import 'package:flutter/material.dart';

/// A sidebar section (e.g. HRMS) with nested leaf destinations.
class AppNavSection {
  const AppNavSection({
    required this.label,
    required this.items,
    this.iconAsset,
    this.icon,
    this.selectable = false,
  });

  final String label;
  final String? iconAsset;
  final IconData? icon;
  final List<AppNavItem> items;

  /// When true, tapping the section label selects its own destination index.
  final bool selectable;
}

/// Clickable leaf item under a section.
class AppNavItem {
  const AppNavItem({
    required this.label,
    this.icon,
    this.iconAsset,
  });

  final String label;
  final IconData? icon;
  final String? iconAsset;
}
