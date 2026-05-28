import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/profile/user_model.dart';

/// Vienintelė QORT dizaino sistemos tiesa — spalvos, tipografija, atstumai, radius.
abstract final class QortDesignSystem {
  // --- Foniniai sluoksniai ---
  static const bgBase = Color(0xFF09090B);
  static const bgSurface = Color(0xFF18181B);
  static const bgElevated = Color(0xFF27272A);
  static const bgInteractive = Color(0xFF3F3F46);

  // --- Sienos ---
  static final borderSubtle = Colors.white.withValues(alpha: 0.06);
  static final borderDefault = Colors.white.withValues(alpha: 0.12);
  static final borderStrong = Colors.white.withValues(alpha: 0.20);

  // --- Tekstas ---
  static const textPrimary = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textMuted = Color(0xFF71717A);
  static const textDisabled = Color(0xFF52525B);

  // --- Režimų akcentai ---
  static const competition = Color(0xFFEAB308);
  static const training = Color(0xFF10B981);
  static const blitz = Color(0xFFD946EF);
  static const brand = Color(0xFF3B82F6);

  // --- Sistemos ---
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  // --- Atstumai (4px scale) ---
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space8 = 32.0;
  static const space12 = 48.0;

  // --- Radius ---
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 24.0;
  static const radiusFull = 999.0;

  // --- Tipografika ---
  static TextStyle get display => GoogleFonts.bebasNeue(
        fontSize: 48,
        height: 1.0,
        color: textPrimary,
      );

  static TextStyle get h1 => GoogleFonts.bebasNeue(
        fontSize: 28,
        height: 1.1,
        color: textPrimary,
      );

  static TextStyle get h2 => GoogleFonts.bebasNeue(
        fontSize: 14,
        letterSpacing: 2,
        color: textSecondary,
      );

  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 15,
        height: 1.5,
        color: textPrimary,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 13,
        color: textSecondary,
      );

  static TextStyle get micro => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      );

  /// Akcentas pagal aplikacijos režimą.
  static Color modeAccent(AppMode mode) {
    switch (mode) {
      case AppMode.competition:
        return competition;
      case AppMode.training:
        return training;
      case AppMode.blitz:
        return blitz;
    }
  }

  /// Numatyta renginio nuotrauka (Unsplash — sporto salė).
  static const eventPlaceholderImage =
      'https://images.unsplash.com/photo-1554068865-24cecd4e9b27?w=800&q=80';
}
