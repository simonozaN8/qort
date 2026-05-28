import 'package:flutter/material.dart';

import '../theme/qort_palette_extension.dart';

/// Profesionalus hero fonas — gradientas ir subtilus raštas, be iliustracijų.
class QortHeroBanner extends StatelessWidget {
  final Color accent;
  final double height;
  final Widget child;

  const QortHeroBanner({
    super.key,
    required this.accent,
    required this.child,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  p.surfaceElevated,
                  Color.lerp(p.surface, accent, 0.08)!,
                  p.background,
                ],
              ),
            ),
          ),
          CustomPaint(
            painter: _QortHeroPatternPainter(
              accent: accent.withValues(alpha: p.isDark ? 0.12 : 0.08),
              lineColor: p.border.withValues(alpha: 0.35),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  p.surface.withValues(alpha: 0.88),
                  p.surface.withValues(alpha: 0.72),
                  p.background.withValues(alpha: 0.94),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _QortHeroPatternPainter extends CustomPainter {
  final Color accent;
  final Color lineColor;

  const _QortHeroPatternPainter({
    required this.accent,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final accentPaint = Paint()..color = accent;
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.2),
      size.width * 0.22,
      accentPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.75),
      size.width * 0.14,
      accentPaint..color = accent.withValues(alpha: accent.a * 0.6),
    );

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (var i = 0.0; i < size.width; i += 28) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _QortHeroPatternPainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.lineColor != lineColor;
  }
}
