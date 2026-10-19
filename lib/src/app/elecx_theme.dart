import 'package:flutter/material.dart';

import 'alien_cockpit_tokens.dart';

abstract final class ElecXTheme {
  static ThemeData light() => _theme(Brightness.light);

  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: dark
          ? AlienCockpitTokens.darkSeed
          : AlienCockpitTokens.lightSeed,
      brightness: brightness,
    );
    final scheme = dark
        ? base.copyWith(
            primary: AlienCockpitTokens.cyan,
            onPrimary: AlienCockpitTokens.darkVoid,
            primaryContainer: const Color(0xFF123D48),
            onPrimaryContainer: AlienCockpitTokens.cyanBright,
            secondary: AlienCockpitTokens.violet,
            secondaryContainer: const Color(0xFF2B2452),
            tertiary: AlienCockpitTokens.aqua,
            tertiaryContainer: const Color(0xFF113D35),
            error: AlienCockpitTokens.fault,
            surface: AlienCockpitTokens.darkCanvas,
            surfaceContainerLowest: AlienCockpitTokens.darkVoid,
            surfaceContainerLow: AlienCockpitTokens.darkPanel,
            surfaceContainer: const Color(0xFF0D1C22),
            surfaceContainerHigh: AlienCockpitTokens.darkPanelRaised,
            surfaceContainerHighest: AlienCockpitTokens.darkPanelHighest,
            onSurface: AlienCockpitTokens.coolText,
            onSurfaceVariant: AlienCockpitTokens.coolMuted,
            outline: AlienCockpitTokens.coolOutlineStrong,
            outlineVariant: AlienCockpitTokens.coolOutline,
          )
        : base.copyWith(
            primary: const Color(0xFF006B7D),
            secondary: const Color(0xFF6655B8),
            tertiary: const Color(0xFF087E68),
            error: const Color(0xFFB3263E),
            outline: const Color(0xFF587078),
            outlineVariant: const Color(0xFFB8C8CD),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      focusColor: scheme.primary.withValues(alpha: 0.18),
      hoverColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.10),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scheme.surfaceContainerLowest,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(
            color: scheme.primary.withValues(alpha: dark ? 0.20 : 0.12),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.66),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(7)),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(7)),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(7)),
          borderSide: BorderSide(color: scheme.error, width: 1.3),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 260),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: scheme.primary.withValues(alpha: dark ? 0.28 : 0.16),
          ),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: const TextStyle(fontSize: 11.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        selectedColor: scheme.primaryContainer.withValues(
          alpha: dark ? 0.82 : 0.55,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(36, 36)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(40, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
