import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/qort_design_system.dart';

/// QORT žodinis logotipas — geltonas Anton tekstas ant skaidraus fono.
class QortLogo extends StatelessWidget {
  /// Palikta suderinamumui su senesniais asset nuorodomis.
  static const assetPath = 'assets/images/qort_logo.png';

  /// Numatytas header dydis (~22–24 px).
  final double fontSize;

  /// Jei `false`, rodoma tik „Q“ raidė (pvz. app icon peržiūrai).
  final bool showWordmark;

  final QortLogoVariant variant;

  const QortLogo({
    super.key,
    double? fontSize,
    double? height,
    this.showWordmark = true,
    this.variant = QortLogoVariant.color,
  }) : fontSize = fontSize ?? height ?? 23;

  Color get _color {
    switch (variant) {
      case QortLogoVariant.monochrome:
      case QortLogoVariant.reversed:
        return QortDesignSystem.textPrimary;
      case QortLogoVariant.color:
        return QortDesignSystem.competition;
    }
  }

  TextStyle _textStyle() {
    return GoogleFonts.anton(
      fontSize: fontSize,
      color: _color,
      letterSpacing: fontSize * 0.02,
      height: 1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      showWordmark ? 'QORT' : 'Q',
      style: _textStyle(),
    );
  }
}

enum QortLogoVariant { color, monochrome, reversed }

/// Kvadratinė app icon peržiūra UI viduje (ne OS launcher).
class QortAppIcon extends StatelessWidget {
  final double size;

  const QortAppIcon({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: QortDesignSystem.bgBase,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: QortDesignSystem.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: QortLogo(
          fontSize: size * 0.55,
          showWordmark: false,
        ),
      ),
    );
  }
}
