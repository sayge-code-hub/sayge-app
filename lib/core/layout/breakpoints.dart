import 'package:flutter/material.dart';

abstract final class Breakpoints {
  /// Persistent sidebar layout (desktop / large tablet landscape).
  static const double desktop = 1024;

  /// Comfortable content width for main panels.
  static const double contentMax = 1440;

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktop;
  }

  static bool isCompact(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 720;
  }
}
