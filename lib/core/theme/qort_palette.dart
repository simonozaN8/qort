import 'package:flutter/material.dart';

import 'qort_design_system.dart';

/// Vizualinio varianto pavadinimas ir spalvų rinkinys.
enum QortThemeVariant {
  premiumLight,
  proDark,
  sportContrast,
}

class QortPalette {
  final String id;
  final String title;
  final String subtitle;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color primary;
  final Color primaryLight;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color navInactive;
  final Color chipSelected;
  final Color chipUnselectedBg;
  final Color chipUnselectedText;
  final Color success;
  final Color listRowAlt;
  final bool isDark;

  const QortPalette({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.primary,
    required this.primaryLight,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.navInactive,
    required this.chipSelected,
    required this.chipUnselectedBg,
    required this.chipUnselectedText,
    required this.success,
    required this.listRowAlt,
    required this.isDark,
  });

  static const premiumLight = QortPalette(
    id: 'premium_light',
    title: 'Premium Light',
    subtitle: 'Šviesus, sluoksniuotas — rekomenduojama admin ir turnyrams',
    background: Color(0xFFF1F5F9),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    primary: Color(0xFF2563EB),
    primaryLight: Color(0xFFEFF6FF),
    accent: Color(0xFF2563EB),
    textPrimary: Color(0xFF0B1220),
    textSecondary: Color(0xFF475569),
    border: Color(0xFFE2E8F0),
    navInactive: Color(0xFF64748B),
    chipSelected: Color(0xFF2563EB),
    chipUnselectedBg: Color(0xFFFFFFFF),
    chipUnselectedText: Color(0xFF475569),
    success: Color(0xFF16A34A),
    listRowAlt: Color(0xFFF8FAFC),
    isDark: false,
  );

  static const proDark = QortPalette(
    id: 'pro_dark',
    title: 'QORT Pro Dark',
    subtitle: 'Tamsus, profesionalus — numatyta visai programėlei',
    background: QortDesignSystem.bgBase,
    surface: QortDesignSystem.bgSurface,
    surfaceElevated: QortDesignSystem.bgElevated,
    primary: QortDesignSystem.brand,
    primaryLight: QortDesignSystem.bgInteractive,
    accent: QortDesignSystem.brand,
    textPrimary: QortDesignSystem.textPrimary,
    textSecondary: QortDesignSystem.textSecondary,
    border: QortDesignSystem.bgInteractive,
    navInactive: QortDesignSystem.textMuted,
    chipSelected: QortDesignSystem.brand,
    chipUnselectedBg: QortDesignSystem.bgElevated,
    chipUnselectedText: QortDesignSystem.textSecondary,
    success: QortDesignSystem.success,
    listRowAlt: QortDesignSystem.bgElevated,
    isDark: true,
  );

  static const sportContrast = QortPalette(
    id: 'sport_contrast',
    title: 'Sport Contrast',
    subtitle: 'Ryškus kontrastas, violetinė energija — vartotojo zona',
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF8FAFC),
    surfaceElevated: Color(0xFFFFFFFF),
    primary: Color(0xFF7C3AED),
    primaryLight: Color(0xFFF3E8FF),
    accent: Color(0xFFD946EF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    border: Color(0xFFCBD5E1),
    navInactive: Color(0xFF64748B),
    chipSelected: Color(0xFFD946EF),
    chipUnselectedBg: Color(0xFFF1F5F9),
    chipUnselectedText: Color(0xFF475569),
    success: Color(0xFF16C56E),
    listRowAlt: Color(0xFFF1F5F9),
    isDark: false,
  );

  static QortPalette forVariant(QortThemeVariant v) {
    switch (v) {
      case QortThemeVariant.premiumLight:
        return premiumLight;
      case QortThemeVariant.proDark:
        return proDark;
      case QortThemeVariant.sportContrast:
        return sportContrast;
    }
  }

  static QortPalette fromId(String? id) {
    switch (id) {
      case 'pro_dark':
        return proDark;
      case 'sport_contrast':
        return sportContrast;
      default:
        return proDark;
    }
  }
}
