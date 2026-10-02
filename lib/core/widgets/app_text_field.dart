import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Shared text field used across the app.
///
/// Clean outline style with white fill, orange focus ring, and
/// black / light-black text. Designed for white surfaces.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final Iterable<String>? autofillHints;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: hasError
                      ? AppColors.error
                      : _isFocused
                          ? AppColors.text
                          : AppColors.textLight,
                ),
          ),
          const SizedBox(height: 6),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            validator: widget.validator,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            onTap: widget.onTap,
            autofillHints: widget.autofillHints,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 14,
                  color: AppColors.text,
                  fontWeight: FontWeight.w400,
                ),
            cursorColor: AppColors.text,
            cursorWidth: 1.5,
            decoration: InputDecoration(
              hintText: widget.hintText,
              helperText: widget.helperText,
              errorText: widget.errorText,
              counterText: '',
              filled: true,
              fillColor: AppColors.background,
              prefixText: widget.prefixText,
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      size: 20,
                      color: hasError
                          ? AppColors.error
                          : _isFocused
                              ? AppColors.text
                              : AppColors.textLight,
                    )
                  : null,
              suffixIcon: widget.suffixIcon,
              suffix: widget.suffix,
            ),
          ),
        ),
      ],
    );
  }
}
