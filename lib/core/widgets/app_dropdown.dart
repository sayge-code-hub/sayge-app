import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.itemLabel,
    this.value,
    this.onChanged,
    this.errorText,
    this.enabled = true,
    this.hintText,
  });

  final String label;
  final List<T> items;
  final String Function(T item) itemLabel;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? errorText;
  final bool enabled;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: hasError ? AppColors.error : AppColors.textLight,
              ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          // ignore: deprecated_member_use
          value: value,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                ),
              )
              .toList(),
          onChanged: enabled ? onChanged : null,
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            filled: true,
            fillColor: AppColors.background,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textLight,
          ),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 14,
                color: AppColors.text,
                fontWeight: FontWeight.w400,
              ),
          dropdownColor: AppColors.background,
        ),
      ],
    );
  }
}
