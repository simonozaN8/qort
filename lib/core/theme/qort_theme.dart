import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'qort_palette.dart';
import 'qort_palette_extension.dart';
import 'qort_typography.dart';

/// Bendras QORT UI — generuojamas iš pasirinkto paletės varianto.
class QortTheme {
  QortTheme._();

  static ThemeData get light => fromPalette(QortPalette.premiumLight);

  static ThemeData fromPalette(QortPalette p) {
    final brightness = p.isDark ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: Colors.white,
      primaryContainer: p.primaryLight,
      onPrimaryContainer: p.textPrimary,
      secondary: p.accent,
      onSecondary: Colors.white,
      secondaryContainer: p.accent.withValues(alpha: 0.15),
      onSecondaryContainer: p.textPrimary,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.surfaceElevated,
      onSurfaceVariant: p.textSecondary,
      outline: p.border,
      outlineVariant: p.border.withValues(alpha: 0.6),
      error: const Color(0xFFDC2626),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.background,
      primaryColor: p.primary,
      colorScheme: colorScheme,
      splashFactory: InkSparkle.splashFactory,
      extensions: [QortPaletteExtension(p)],
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: QortTypography.displayMedium(p),
        systemOverlayStyle: p.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: p.isDark ? 0.35 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? p.primary : p.navInactive,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: p.isDark ? p.surfaceElevated : p.textPrimary,
        contentTextStyle: TextStyle(color: p.isDark ? p.textPrimary : Colors.white),
      ),
      dividerColor: p.border,
      textTheme: QortTypography.textTheme(p),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: QortTypography.button(p),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          backgroundColor: p.surface,
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.isDark ? p.surfaceElevated : p.surface,
        hintStyle: QortTypography.bodySecondary(p, size: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        labelStyle: QortTypography.bodySecondary(p, size: 13),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.chipUnselectedBg,
        selectedColor: p.chipSelected,
        labelStyle: QortTypography.caption(p),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide(color: p.border),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceElevated,
        modalBackgroundColor: p.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border),
        ),
      ),
    );
  }

  static BoxDecoration card(
    QortPalette p, {
    Color? borderColor,
    Color? leftAccent,
  }) {
    return BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor ?? leftAccent ?? p.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: p.isDark ? 0.25 : 0.04),
          blurRadius: p.isDark ? 16 : 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static TextStyle sectionTitle(QortPalette p) =>
      QortTypography.sectionLabel(p);

  static BoxDecoration bottomSheet(QortPalette p) => BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: p.border)),
      );

  static BoxDecoration inputField(QortPalette p) => BoxDecoration(
        color: p.isDark ? p.surfaceElevated : p.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      );

  static ThemeData pickerTheme(BuildContext context) {
    final p = context.qortPalette;
    return Theme.of(context).copyWith(
      colorScheme: ColorScheme(
        brightness: p.isDark ? Brightness.dark : Brightness.light,
        primary: p.primary,
        onPrimary: Colors.white,
        secondary: p.accent,
        onSecondary: Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
        error: const Color(0xFFDC2626),
        onError: Colors.white,
      ),
    );
  }
}
