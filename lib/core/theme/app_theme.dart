import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const String _fontFamily = 'PlusJakartaSans';

  static ThemeData get light {
    final baseTextTheme = ThemeData.light().textTheme.apply(
      fontFamily: _fontFamily,
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: _fontFamily,
      // Instant route changes — no platform fade/slide between pages.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _NoTransitionsBuilder(),
          TargetPlatform.iOS: _NoTransitionsBuilder(),
          TargetPlatform.macOS: _NoTransitionsBuilder(),
          TargetPlatform.windows: _NoTransitionsBuilder(),
          TargetPlatform.linux: _NoTransitionsBuilder(),
        },
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.text,
        onPrimary: AppColors.background,
        secondary: AppColors.success,
        onSecondary: AppColors.background,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.error,
        onError: AppColors.background,
        outline: AppColors.border,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.0,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.textLight,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: _outline(AppColors.border),
        enabledBorder: _outline(AppColors.border),
        focusedBorder: _outline(AppColors.text, width: 1.25),
        errorBorder: _outline(AppColors.error),
        focusedErrorBorder: _outline(AppColors.error, width: 1.25),
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: AppColors.textLight,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: AppColors.textLight,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: AppColors.border, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.text;
          }
          return AppColors.background;
        }),
        checkColor: WidgetStateProperty.all(AppColors.background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.text,
          foregroundColor: AppColors.background,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.text,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.text,
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: AppColors.background,
          fontWeight: FontWeight.w400,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static OutlineInputBorder _outline(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
