import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/cafe_guest_menu_api.dart';
import '../../domain/entities/cafe_entities.dart';

/// Resolved colors for the public guest QR menu.
class GuestMenuTheme {
  const GuestMenuTheme({
    required this.accent,
    required this.layout,
    required this.showLogo,
    required this.showSearch,
    required this.tagline,
    this.logoUrl,
  });

  final Color accent;
  final GuestMenuLayout layout;
  final bool showLogo;
  final bool showSearch;
  final String tagline;
  final String? logoUrl;

  factory GuestMenuTheme.fromBrand(GuestCafeBrand brand) {
    return GuestMenuTheme(
      accent: parseAccentHex(brand.accentHex) ?? AppColors.highlight,
      layout: brand.layout,
      showLogo: brand.showLogo && (brand.logoUrl?.isNotEmpty ?? false),
      showSearch: brand.showSearch,
      tagline: brand.tagline.trim(),
      logoUrl: brand.logoUrl,
    );
  }

  static Color? parseAccentHex(String raw) {
    var hex = raw.trim();
    if (hex.isEmpty) return null;
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  static const accentPresets = <(String, String)>[
    ('Coral', '#FF6B4A'),
    ('Forest', '#1B7A4E'),
    ('Espresso', '#3D2B1F'),
    ('Ocean', '#1F6F8B'),
    ('Berry', '#9B2D5A'),
    ('Slate', '#334155'),
  ];
}
