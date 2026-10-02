import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_text_field.dart';

/// Password field built on [AppTextField] with show/hide toggle.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    this.controller,
    this.focusNode,
    this.label = 'Password',
    this.hintText,
    this.errorText,
    this.textInputAction = TextInputAction.done,
    this.enabled = true,
    this.autofocus = false,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hintText;
  final String? errorText;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool autofocus;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      label: widget.label,
      hintText: widget.hintText,
      errorText: widget.errorText,
      prefixIcon: Icons.lock_outline_rounded,
      obscureText: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscureText = !_obscureText),
        splashRadius: 20,
        tooltip: _obscureText ? 'Show password' : 'Hide password',
        icon: Icon(
          _obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 20,
          color: AppColors.textLight,
        ),
      ),
    );
  }
}
