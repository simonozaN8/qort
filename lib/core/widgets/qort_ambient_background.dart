import 'package:flutter/material.dart';

import '../theme/qort_palette.dart';

/// Subtilus tamsus fonas su „gyvybės“ akcentais (kaip QORT mockup).
class QortAmbientBackground extends StatelessWidget {
  final QortPalette palette;

  const QortAmbientBackground({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    if (!palette.isDark) {
      return ColoredBox(color: palette.background);
    }

    return ColoredBox(
      color: palette.background,
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _orb(palette.primary.withValues(alpha: 0.22), 220),
          ),
          Positioned(
            top: 120,
            left: -100,
            child: _orb(palette.accent.withValues(alpha: 0.14), 260),
          ),
          Positioned(
            bottom: -40,
            right: 40,
            child: _orb(const Color(0xFFD946EF).withValues(alpha: 0.08), 180),
          ),
        ],
      ),
    );
  }

  Widget _orb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
