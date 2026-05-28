import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'qort_palette.dart';

/// Tipografijos skalė — vienas šaltinis visiems ekranams.
///
/// Hierarchija (world-class sports UI):
/// - **Bebas Neue** — display, CTA, hero antraštės
/// - **Oswald** — sekcijų etiketės, statistika, turnyrų UI
/// - **Inter** — body, formos, ilgesnis tekstas
class QortTypography {
  QortTypography._();

  /// Paleidimo metu užkrauna šriftus — mažiau „pops“ pirmame render'yje.
  static Future<void> preload() async {
    await GoogleFonts.pendingFonts([
      GoogleFonts.inter(),
      GoogleFonts.bebasNeue(),
      GoogleFonts.oswald(),
    ]);
  }

  static TextTheme textTheme(QortPalette p) {
    final base = ThemeData(brightness: p.isDark ? Brightness.dark : Brightness.light)
        .textTheme;

    return GoogleFonts.interTextTheme(base).apply(
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
    );
  }

  /// Hero / ekrano antraštė (Bebas Neue).
  static TextStyle displayLarge(QortPalette p, {Color? color}) =>
      GoogleFonts.bebasNeue(
        fontSize: 28,
        height: 1.05,
        letterSpacing: 0.5,
        color: color ?? p.textPrimary,
      );

  /// Modalų / sheet antraštės.
  static TextStyle displayMedium(QortPalette p, {Color? color}) =>
      GoogleFonts.bebasNeue(
        fontSize: 22,
        height: 1.1,
        letterSpacing: 1,
        color: color ?? p.textPrimary,
      );

  /// Mygtukų tekstas.
  static TextStyle button(QortPalette p, {Color? color}) =>
      GoogleFonts.bebasNeue(
        fontSize: 16,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w400,
        color: color ?? Colors.white,
      );

  /// Sekcijų etiketės (OSWALD caps).
  static TextStyle sectionLabel(QortPalette p, {Color? color}) =>
      GoogleFonts.oswald(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: color ?? p.textSecondary,
      );

  /// Statistikos skaičiai, turnyrų progresas.
  static TextStyle stat(QortPalette p, {double size = 24, Color? color}) =>
      GoogleFonts.oswald(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? p.textPrimary,
      );

  /// Standartinis body.
  static TextStyle body(QortPalette p, {double size = 14, Color? color}) =>
      GoogleFonts.inter(
        fontSize: size,
        height: 1.45,
        color: color ?? p.textPrimary,
      );

  static TextStyle bodySecondary(QortPalette p, {double size = 13}) =>
      body(p, size: size, color: p.textSecondary);

  static TextStyle caption(QortPalette p, {Color? color}) =>
      GoogleFonts.inter(
        fontSize: 11,
        height: 1.35,
        color: color ?? p.textSecondary,
      );
}
