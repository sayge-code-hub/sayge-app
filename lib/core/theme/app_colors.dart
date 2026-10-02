import 'package:flutter/material.dart';

/// Strict app palette — only these roles are allowed.
///
/// 1. [background] — white (cards, inputs)
/// 2. [surface] — very light off-white (main content pane)
/// 3. [surfaceMuted] — slightly deeper off-white (sidebar)
/// 4. [border] — lightest grey (dividers, inputs, cards)
/// 5. [highlight] — orange (brand accent; use sparingly)
/// 6. [text] / [textLight] — black / light black
/// 7. [error] / [success] — red / green
abstract final class AppColors {
  /// Pure white for cards, inputs, and raised panels.
  static const Color background = Color(0xFFFFFFFF);

  /// Very light off-white for the main content pane.
  static const Color surface = Color(0xFFFAFAFA);

  /// Slightly deeper off-white for sidebar / muted chrome.
  static const Color surfaceMuted = Color(0xFFF5F5F5);

  /// Lightest grey for borders and hairlines.
  static const Color border = Color(0xFFE8E8E8);

  /// Brand orange. Prefer black for interactive chrome; keep orange rare.
  static const Color highlight = Color(0xFFFF6B4A);

  static const Color text = Color(0xFF111111);
  static const Color textLight = Color(0xFF6B7280);

  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
}
