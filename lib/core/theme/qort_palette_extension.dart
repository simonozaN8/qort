import 'package:flutter/material.dart';

import 'qort_palette.dart';

class QortPaletteExtension extends ThemeExtension<QortPaletteExtension> {
  final QortPalette palette;

  const QortPaletteExtension(this.palette);

  @override
  QortPaletteExtension copyWith({QortPalette? palette}) {
    return QortPaletteExtension(palette ?? this.palette);
  }

  @override
  QortPaletteExtension lerp(
    covariant ThemeExtension<QortPaletteExtension>? other,
    double t,
  ) {
    if (other is! QortPaletteExtension) return this;
    return QortPaletteExtension(palette);
  }
}

extension QortPaletteContext on BuildContext {
  QortPalette get qortPalette {
    final ext = Theme.of(this).extension<QortPaletteExtension>();
    return ext?.palette ?? QortPalette.premiumLight;
  }
}
