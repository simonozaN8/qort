import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/qort_palette_extension.dart';

/// Tinklo vaizdas su kešu — tinka masiniam naudojimui (avatarai, logotipai).
class QortNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const QortNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return SizedBox(width: width, height: height);
    }

    final p = context.qortPalette;
    final image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: width != null ? (width! * 2).round() : 256,
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: p.listRowAlt,
        alignment: Alignment.center,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: p.primary.withValues(alpha: 0.6),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        width: width,
        height: height,
        color: p.listRowAlt,
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined, color: p.textSecondary, size: 20),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
