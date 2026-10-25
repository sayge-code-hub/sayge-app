import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One choice in an [AppFilterDropdown].
class AppFilterOption<T> {
  const AppFilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Compact filter menu that matches the height and outline of list [FilterChip]s.
///
/// Use this for toolbar filters. Form fields should keep using [AppDropdown].
class AppFilterDropdown<T> extends StatelessWidget {
  const AppFilterDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  /// Outer height of the employees-list status chips, including the border.
  static const double height = 44;

  static const double radius = 8;

  final T value;
  final List<AppFilterOption<T>> options;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    final hasValue = options.any((option) => option.value == value);
    final selected = hasValue ? value : options.first.value;
    final canChange = enabled && onChanged != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final expand =
            constraints.hasBoundedWidth &&
            constraints.maxWidth.isFinite &&
            constraints.minWidth >= constraints.maxWidth;

        final closedStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 12,
          height: 1,
          color: canChange ? AppColors.text : AppColors.textLight,
        );
        final menuStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: 13,
          color: AppColors.text,
          fontWeight: FontWeight.w400,
        );

        return SizedBox(
          height: height,
          width: expand ? constraints.maxWidth : null,
          child: Theme(
            data: Theme.of(
              context,
            ).copyWith(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Material(
              color: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
                side: const BorderSide(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: selected,
                  isDense: true,
                  isExpanded: expand,
                  padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
                  borderRadius: BorderRadius.circular(radius),
                  dropdownColor: AppColors.background,
                  elevation: 2,
                  focusColor: Colors.transparent,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  iconSize: 18,
                  iconEnabledColor: AppColors.textLight,
                  iconDisabledColor: AppColors.textLight,
                  style: closedStyle,
                  onChanged: canChange ? (next) => onChanged!(next as T) : null,
                  selectedItemBuilder: (context) => [
                    for (final option in options)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          option.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: closedStyle,
                        ),
                      ),
                  ],
                  items: [
                    for (final option in options)
                      DropdownMenuItem<T>(
                        value: option.value,
                        child: Text(
                          option.label,
                          overflow: TextOverflow.ellipsis,
                          style: menuStyle?.copyWith(
                            fontWeight: option.value == selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
