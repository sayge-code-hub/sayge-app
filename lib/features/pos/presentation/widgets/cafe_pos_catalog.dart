import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_filter_dropdown.dart';
import '../../domain/entities/cafe_entities.dart';
import 'cafe_pos_chrome.dart';

/// Category filter — chips when few, [AppFilterDropdown] when many.
class CafePosCategoryBar extends StatelessWidget {
  const CafePosCategoryBar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.allLabel = 'All Items',
    this.chipThreshold = 5,
  });

  final List<CafeCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final String allLabel;

  /// Use a dropdown when category count exceeds this (matches other modules).
  final int chipThreshold;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    if (categories.length > chipThreshold) {
      return SizedBox(
        width: double.infinity,
        child: AppFilterDropdown<String?>(
          value: selectedId,
          options: [
            AppFilterOption<String?>(value: null, label: allLabel),
            for (final c in categories)
              AppFilterOption<String?>(value: c.id, label: c.name),
          ],
          onChanged: onSelected,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _CategoryChip(
          label: allLabel,
          selected: selectedId == null,
          onSelected: () => onSelected(null),
        ),
        for (final c in categories)
          _CategoryChip(
            label: c.name,
            selected: selectedId == c.id,
            onSelected: () => onSelected(c.id),
          ),
      ],
    );
  }
}

/// Same chip shape / colors as employees list [FilterChip]s.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppFilterDropdown.radius),
      ),
      selectedColor: AppColors.highlight,
      backgroundColor: AppColors.background,
      side: const BorderSide(color: AppColors.border),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 12,
            height: 1,
            color: selected ? AppColors.background : AppColors.text,
          ),
    );
  }
}

/// Circular monogram used as product visual (no image URLs yet).
class CafePosProductThumb extends StatelessWidget {
  const CafePosProductThumb({
    super.key,
    required this.name,
    this.size = 56,
  });

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CafePosMonogram(label: name, size: size);
  }
}

/// Product tile for terminal (qty +/−) or menu (edit).
class CafePosProductCard extends StatelessWidget {
  const CafePosProductCard({
    super.key,
    required this.item,
    this.onTap,
    this.onAdd,
    this.onRemove,
    this.quantity = 0,
    this.mode = CafePosProductCardMode.add,
    this.showUnavailable = false,
  });

  final CafeMenuItem item;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final int quantity;
  final CafePosProductCardMode mode;
  final bool showUnavailable;

  @override
  Widget build(BuildContext context) {
    final unavailable = showUnavailable && !item.isAvailable;
    final qty = quantity;
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CafePosSpace.radius),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Edit mode: open item. Terminal: tap card to add / bump qty; use − to remove.
        onTap: mode == CafePosProductCardMode.edit ? onTap : onAdd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Opacity(
                  opacity: unavailable ? 0.45 : 1,
                  child: Center(
                    child: CafePosProductThumb(name: item.name, size: 48),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: unavailable
                          ? AppColors.textLight
                          : AppColors.text,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                MoneyFormat.format(item.price),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.highlight,
                    ),
              ),
              const SizedBox(height: 8),
              if (mode == CafePosProductCardMode.edit)
                Align(
                  alignment: Alignment.centerRight,
                  child: _roundIcon(Icons.edit_rounded),
                )
              else if (qty <= 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: _roundIcon(Icons.add_rounded),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Absorb tap so parent card doesn't also +1 when pressing −.
                    GestureDetector(
                      onTap: onRemove,
                      behavior: HitTestBehavior.opaque,
                      child: _roundIcon(
                        Icons.remove_rounded,
                        filled: false,
                      ),
                    ),
                    Text(
                      '$qty',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    _roundIcon(Icons.add_rounded),
                  ],
                ),
              if (unavailable) ...[
                const SizedBox(height: 4),
                Text(
                  'Unavailable',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                        fontSize: 10,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundIcon(
    IconData icon, {
    VoidCallback? onPressed,
    bool filled = true,
  }) {
    return Material(
      color: filled
          ? AppColors.highlight.withValues(alpha: 0.12)
          : AppColors.surfaceMuted,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 16, color: AppColors.highlight),
        ),
      ),
    );
  }
}

enum CafePosProductCardMode { add, edit }

class CafePosProductGrid extends StatelessWidget {
  const CafePosProductGrid({
    super.key,
    required this.items,
    this.onItemTap,
    this.onAdd,
    this.onRemove,
    this.mode = CafePosProductCardMode.add,
    this.showUnavailable = false,
    this.qtyFor,
    this.padding,
    this.empty,
  });

  final List<CafeMenuItem> items;
  final ValueChanged<CafeMenuItem>? onItemTap;
  final ValueChanged<CafeMenuItem>? onAdd;
  final ValueChanged<CafeMenuItem>? onRemove;
  final CafePosProductCardMode mode;
  final bool showUnavailable;
  final int Function(CafeMenuItem item)? qtyFor;
  final EdgeInsetsGeometry? padding;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return empty ??
          const CafePosEmptyState(
            icon: Icons.restaurant_menu_outlined,
            title: 'No items',
            message: 'Nothing in this category.',
          );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Denser on large screens so tiles stay compact.
        final cross = w >= 1400
            ? 6
            : w >= 1100
                ? 5
                : w >= 820
                    ? 4
                    : w >= 560
                        ? 3
                        : 2;
        return GridView.builder(
          padding: padding ?? const EdgeInsets.fromLTRB(0, 4, 0, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: cross >= 5 ? 0.95 : (cross >= 4 ? 0.9 : 0.82),
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final qty = qtyFor?.call(item) ?? 0;
            return CafePosProductCard(
              item: item,
              mode: mode,
              quantity: qty,
              showUnavailable: showUnavailable,
              onTap: onItemTap == null ? null : () => onItemTap!(item),
              onAdd: onAdd == null ? null : () => onAdd!(item),
              onRemove: onRemove == null ? null : () => onRemove!(item),
            );
          },
        );
      },
    );
  }
}

/// Compact qty stepper for cart rows.
class CafePosQtyStepper extends StatelessWidget {
  const CafePosQtyStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove_rounded, () => onChanged(quantity - 1)),
        SizedBox(
          width: 28,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        _btn(Icons.add_rounded, () => onChanged(quantity + 1)),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppColors.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 16, color: AppColors.text),
        ),
      ),
    );
  }
}

/// Sticky bottom action bar (Add cafe / Add item / Add category).
class CafePosStickyAction extends StatelessWidget {
  const CafePosStickyAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.text,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
