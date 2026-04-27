import 'package:flutter/material.dart';

import 'tokens.dart';

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// SF Pro / system stack — matches the design's --font-sans.
  static const _systemStack = [
    'SF Pro Display',
    'SF Pro Text',
    '-apple-system',
    'BlinkMacSystemFont',
    'Helvetica Neue',
    'Helvetica',
    'Arial',
  ];

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;

    final scheme = ColorScheme(
      brightness: b,
      primary: dark ? AuroraTokens.p80 : AuroraTokens.p40,
      onPrimary: dark ? AuroraTokens.p20 : Colors.white,
      primaryContainer: dark ? AuroraTokens.p30 : AuroraTokens.p90,
      onPrimaryContainer: dark ? AuroraTokens.p90 : AuroraTokens.p10,
      secondary: dark ? AuroraTokens.s80 : AuroraTokens.s40,
      onSecondary: dark ? AuroraTokens.s20 : Colors.white,
      secondaryContainer: dark ? AuroraTokens.s30 : AuroraTokens.s90,
      onSecondaryContainer: dark ? AuroraTokens.s90 : AuroraTokens.s10,
      tertiary: dark ? AuroraTokens.t80 : AuroraTokens.t40,
      onTertiary: dark ? AuroraTokens.t20 : Colors.white,
      tertiaryContainer: dark ? AuroraTokens.t30 : AuroraTokens.t90,
      onTertiaryContainer: dark ? AuroraTokens.t90 : AuroraTokens.t10,
      error: dark ? AuroraTokens.e80 : AuroraTokens.e40,
      onError: dark ? AuroraTokens.e20 : Colors.white,
      errorContainer: dark ? AuroraTokens.e30 : AuroraTokens.e90,
      onErrorContainer: dark ? AuroraTokens.e90 : AuroraTokens.e10,
      surface: dark ? AuroraTokens.n6 : AuroraTokens.n98,
      onSurface: dark ? AuroraTokens.n90 : AuroraTokens.n10,
      onSurfaceVariant: dark ? AuroraTokens.nv80 : AuroraTokens.nv30,
      surfaceContainerLowest: dark ? AuroraTokens.n4 : AuroraTokens.n100,
      surfaceContainerLow: dark ? AuroraTokens.n10 : AuroraTokens.n96,
      surfaceContainer: dark ? AuroraTokens.n12 : AuroraTokens.n94,
      surfaceContainerHigh: dark ? AuroraTokens.n17 : AuroraTokens.n92,
      surfaceContainerHighest: dark ? AuroraTokens.n22 : AuroraTokens.n90,
      surfaceBright: dark ? AuroraTokens.n24 : AuroraTokens.n98,
      surfaceDim: dark ? AuroraTokens.n6 : AuroraTokens.n87,
      outline: dark ? AuroraTokens.nv60 : AuroraTokens.nv50,
      outlineVariant: dark ? AuroraTokens.nv30 : AuroraTokens.nv80,
      inverseSurface: dark ? AuroraTokens.n90 : AuroraTokens.n20,
      onInverseSurface: dark ? AuroraTokens.n20 : AuroraTokens.n95,
      inversePrimary: dark ? AuroraTokens.p40 : AuroraTokens.p80,
      scrim: Colors.black,
      shadow: Colors.black,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
    );

    // Type scale ported from the design (px → logical pixels).
    final tt = base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontSize: 56, fontWeight: FontWeight.w700,
        letterSpacing: -1.5, height: 1.0,
      ),
      displayMedium: const TextStyle(
        fontSize: 44, fontWeight: FontWeight.w700,
        letterSpacing: -1.0, height: 1.05,
      ),
      displaySmall: const TextStyle(
        fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5,
      ),
      headlineLarge: const TextStyle(
        fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.3,
      ),
      headlineMedium: const TextStyle(
        fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.2,
      ),
      headlineSmall: const TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600,
      ),
      titleLarge: const TextStyle(
        fontSize: 17, fontWeight: FontWeight.w600,
      ),
      titleMedium: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600,
      ),
      titleSmall: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600,
      ),
      bodyLarge: const TextStyle(fontSize: 15, height: 1.5),
      bodyMedium: const TextStyle(fontSize: 13, height: 1.5),
      bodySmall: const TextStyle(fontSize: 11, height: 1.5),
      labelLarge: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.1,
      ),
      labelMedium: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.2,
      ),
      labelSmall: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6,
      ),
    ).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      fontFamilyFallback: _systemStack,
    );

    return base.copyWith(
      textTheme: tt,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuroraTokens.shapeSm),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuroraTokens.shapeSm),
          ),
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: const Size(0, 26),
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      dividerColor: scheme.outlineVariant,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuroraTokens.shapeSm),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuroraTokens.shapeXl),
        ),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13,
          height: 1.5,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        linearMinHeight: 4,
      ),
    );
  }
}
