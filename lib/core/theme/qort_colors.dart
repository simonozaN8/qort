import 'package:flutter/material.dart';

import 'qort_design_system.dart';

/// Legacy spalvų aliasai — visi nukreipti į [QortDesignSystem].
/// Naujame kode naudokite `context.qortPalette` arba `QortDesignSystem`.
class QortColors {
  QortColors._();

  static const brandBlue = QortDesignSystem.brand;
  static const brandCyan = Color(0xFF22C5E6);
  static const brandGreen = QortDesignSystem.training;
  static const brandNavy = QortDesignSystem.bgBase;

  static const background = QortDesignSystem.bgBase;
  static const surface = QortDesignSystem.bgSurface;
  static const surfaceElevated = QortDesignSystem.bgElevated;
  static const primary = QortDesignSystem.brand;
  static const primaryLight = QortDesignSystem.bgElevated;
  static const accent = QortDesignSystem.brand;
  static const textPrimary = QortDesignSystem.textPrimary;
  static const textSecondary = QortDesignSystem.textSecondary;
  static const border = QortDesignSystem.bgInteractive;
  static const navInactive = QortDesignSystem.textMuted;
  static const success = QortDesignSystem.success;
  static const listRowAlt = QortDesignSystem.bgElevated;
}
