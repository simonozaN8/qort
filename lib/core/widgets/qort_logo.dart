import 'package:flutter/material.dart';

import '../theme/qort_colors.dart';
import '../theme/qort_palette_extension.dart';

/// QORT logotipas — naudoja oficialų PNG iš brand gido.
class QortLogo extends StatelessWidget {
  static const assetPath = 'assets/images/qort_logo.png';

  final double height;
  final bool showWordmark;
  final QortLogoVariant variant;

  const QortLogo({
    super.key,
    this.height = 32,
    this.showWordmark = true,
    this.variant = QortLogoVariant.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;

    if (variant == QortLogoVariant.reversed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: p.isDark ? p.surfaceElevated : QortColors.brandNavy,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        child: _LogoImage(
          height: height,
          markOnly: !showWordmark,
          color: p.textPrimary,
          blendMode: BlendMode.srcIn,
        ),
      );
    }

    if (variant == QortLogoVariant.monochrome) {
      return _LogoImage(
        height: height,
        markOnly: !showWordmark,
        color: p.textPrimary,
        blendMode: BlendMode.srcIn,
      );
    }

    // Tamsioje temoje — pilnas spalvotas logotipas ant tamsaus fono.
    return _LogoImage(
      height: height,
      markOnly: !showWordmark,
    );
  }
}

enum QortLogoVariant { color, monochrome, reversed }

class _LogoImage extends StatelessWidget {
  final double height;
  final bool markOnly;
  final Color? color;
  final BlendMode? blendMode;

  const _LogoImage({
    required this.height,
    this.markOnly = false,
    this.color,
    this.blendMode,
  });

  @override
  Widget build(BuildContext context) {
    final width = markOnly ? height * 1.05 : height * 3.2;

    Widget image = Image.asset(
      QortLogo.assetPath,
      height: height,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      cacheWidth: (width * 2).round(),
      alignment: markOnly ? Alignment.centerLeft : Alignment.center,
      errorBuilder: (_, __, ___) => _FallbackLogo(
        height: height,
        width: width,
        markOnly: markOnly,
        tint: color,
      ),
    );

    if (markOnly) {
      image = ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 0.32,
          child: image,
        ),
      );
    }

    if (color != null && blendMode != null) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(color!, blendMode!),
        child: image,
      );
    }

    return image;
  }
}

class _FallbackLogo extends StatelessWidget {
  final double height;
  final double width;
  final bool markOnly;
  final Color? tint;

  const _FallbackLogo({
    required this.height,
    required this.width,
    required this.markOnly,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final color = tint ?? p.primary;
    return SizedBox(
      height: height,
      width: width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports, color: color, size: height * 0.85),
          if (!markOnly) ...[
            const SizedBox(width: 6),
            Text(
              'QORT',
              style: TextStyle(
                color: color,
                fontSize: height * 0.55,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class QortAppIcon extends StatelessWidget {
  final double size;

  const QortAppIcon({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: QortLogo(
          height: size * 0.55,
          showWordmark: false,
        ),
      ),
    );
  }
}
