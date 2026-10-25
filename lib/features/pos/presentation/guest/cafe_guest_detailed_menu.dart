import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_filter_dropdown.dart';
import '../../domain/entities/cafe_entities.dart';

/// Soft green palette for the guest Detailed View.
class DetailedMenuColors {
  static const green = Color(0xFF3DDC84);
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
  return tones[seed.hashCode.abs() % tones.length];
}

/// Guest QR menu — Detailed View only.
class CafeGuestDetailedMenu extends StatefulWidget {
  const CafeGuestDetailedMenu({
    super.key,
    required this.cafeName,
    required this.tableNo,
    required this.categories,
    required this.items,
    required this.cart,
    required this.qtyForConfig,
    required this.onBump,
    required this.onOpenCart,
    required this.searchController,
    required this.onSearch,
    this.showSearch = true,
  });

  final String cafeName;
  final String tableNo;
  final List<CafeCategory> categories;
  final List<CafeMenuItem> items;
  final List<CafeCartLine> cart;
  final int Function(
    CafeMenuItem item, {
    required List<CafeMenuAddon> addons,
    required String notes,
  }) qtyForConfig;
  final void Function(
    CafeMenuItem item, {
    required List<CafeMenuAddon> addons,
    required String notes,
    required int delta,
  }) onBump;
  final VoidCallback onOpenCart;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final bool showSearch;

  @override
  State<CafeGuestDetailedMenu> createState() => _CafeGuestDetailedMenuState();
}

class _CafeGuestDetailedMenuState extends State<CafeGuestDetailedMenu> {
  String? _categoryId;
  CafeMenuItem? _detail;

  Color get _green => DetailedMenuColors.green;

  int get _cartCount =>
      widget.cart.fold<int>(0, (s, l) => s + l.quantity.round());

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

  @override
  Widget build(BuildContext context) {
    if (_detail != null) {
      return _DetailedItemScreen(
        item: _detail!,
        green: _green,
        qtyForConfig: widget.qtyForConfig,
        onBump: widget.onBump,
        onBack: () => setState(() => _detail = null),
      );
    }

    return ColoredBox(
      color: DetailedMenuColors.bg,
      child: SafeArea(
        child: Column(
          children: [
            _searchCartRow(),
            if (widget.categories.isNotEmpty) _categoryDropdown(),
            Expanded(
              child: _grid.isEmpty
                  ? const Center(
                      child: Text(
                        'Nothing here yet.',
                        style: TextStyle(
                          color: DetailedMenuColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: _grid.length,
                      itemBuilder: (context, index) {
                        final item = _grid[index];
                        return _MenuCard(
                          item: item,
                          green: _green,
                          onTap: () => setState(() => _detail = item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchCartRow() {
    final tip = widget.tableNo.isEmpty
        ? widget.cafeName
        : '${widget.cafeName} · T${widget.tableNo}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
      child: Row(
        children: [
          if (widget.showSearch)
            Expanded(
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
                    prefixIcon:
                        Icon(Icons.search_rounded, color: _green, size: 22),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                tip,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: DetailedMenuColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: widget.onOpenCart,
                style: IconButton.styleFrom(
                  backgroundColor: DetailedMenuColors.card,
                  foregroundColor: DetailedMenuColors.ink,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                ),
                icon: const Icon(Icons.shopping_bag_outlined, size: 24),
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
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
    );
  }

  Widget _categoryDropdown() {
    final options = <AppFilterOption<String?>>[
      const AppFilterOption(value: null, label: 'All categories'),
      for (final c in widget.categories)
        AppFilterOption(value: c.id, label: c.name),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: AppFilterDropdown<String?>(
          value: _categoryId,
          options: options,
          onChanged: (id) {
            HapticFeedback.selectionClick();
            setState(() => _categoryId = id);
          },
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.item,
    required this.green,
    required this.onTap,
  });

  final CafeMenuItem item;
  final Color green;
  final VoidCallback onTap;

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
              child: ColoredBox(
                color: tone,
                child: Center(
                  child: Text(
                    _initials(item.name),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: green.withValues(alpha: 0.8),
                    ),
                  ),
                ),
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
                      MoneyFormat.format(item.price),
                      style: TextStyle(
                        color: green,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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

class _DetailedItemScreen extends StatefulWidget {
  const _DetailedItemScreen({
    required this.item,
    required this.green,
    required this.qtyForConfig,
    required this.onBump,
    required this.onBack,
  });

  final CafeMenuItem item;
  final Color green;
  final int Function(
    CafeMenuItem item, {
    required List<CafeMenuAddon> addons,
    required String notes,
  }) qtyForConfig;
  final void Function(
    CafeMenuItem item, {
    required List<CafeMenuAddon> addons,
    required String notes,
    required int delta,
  }) onBump;
  final VoidCallback onBack;

  @override
  State<_DetailedItemScreen> createState() => _DetailedItemScreenState();
}

class _DetailedItemScreenState extends State<_DetailedItemScreen> {
  late final TextEditingController _notes;
  final Set<String> _selectedAddonIds = {};

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController();
    _notes.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  List<CafeMenuAddon> get _selectedAddons => widget.item.addons
      .where((a) => _selectedAddonIds.contains(a.id))
      .toList();

  String get _notesText => _notes.text.trim();

  int get _qty => widget.qtyForConfig(
        widget.item,
        addons: _selectedAddons,
        notes: _notesText,
      );

  double get _unitPrice {
    final extras =
        _selectedAddons.fold<double>(0, (s, a) => s + a.price);
    return widget.item.price + extras;
  }

  void _bump(int delta) {
    HapticFeedback.selectionClick();
    widget.onBump(
      widget.item,
      addons: _selectedAddons,
      notes: _notesText,
      delta: delta,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final green = widget.green;
    final tone = _toneFor(item.id);
    final desc = item.description.trim();

    return ColoredBox(
      color: DetailedMenuColors.bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  color: DetailedMenuColors.ink,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
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
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: green.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: DetailedMenuColors.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    MoneyFormat.format(item.price),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: green,
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      desc,
                      style: const TextStyle(
                        color: DetailedMenuColors.muted,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (item.addons.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const Text(
                      'Add-ons',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: DetailedMenuColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final a in item.addons)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: green,
                        value: _selectedAddonIds.contains(a.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedAddonIds.add(a.id);
                            } else {
                              _selectedAddonIds.remove(a.id);
                            }
                          });
                        },
                        title: Text(
                          a.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: DetailedMenuColors.ink,
                          ),
                        ),
                        secondary: Text(
                          a.price <= 0
                              ? 'Free'
                              : '+ ${MoneyFormat.format(a.price)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: DetailedMenuColors.ink,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'Special instructions',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: DetailedMenuColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    maxLength: 200,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: DetailedMenuColors.ink,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. less sugar, no ice…',
                      hintStyle: TextStyle(
                        color: DetailedMenuColors.muted.withValues(alpha: 0.9),
                      ),
                      filled: true,
                      fillColor: DetailedMenuColors.card,
                      counterText: '',
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: DetailedMenuColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: DetailedMenuColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: green, width: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _stickyBar(green),
          ],
        ),
      ),
    );
  }

  Widget _stickyBar(Color green) {
    final qty = _qty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
        child: qty == 0
            ? FilledButton(
                onPressed: () => _bump(1),
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
                child: Text('Add · ${MoneyFormat.format(_unitPrice)}'),
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _bump(-1),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DetailedMenuColors.ink,
                        side: const BorderSide(color: DetailedMenuColors.line),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Icon(Icons.remove_rounded),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      onPressed: () => _bump(1),
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
      ),
    );
  }
}
