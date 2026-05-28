import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_palette_extension.dart';

class StatusAvatar extends StatelessWidget {
  final String imageUrl;
  final String displayName;
  final double radius;
  final int xp;
  final int winStreak;
  final bool isVerified;

  const StatusAvatar({
    super.key,
    required this.imageUrl,
    required this.displayName,
    this.radius = 20,
    this.xp = 0,
    this.winStreak = 0,
    this.isVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    BoxBorder? border;
    List<BoxShadow> shadows = [];

    final isOnFire = winStreak >= 3;

    if (xp >= 10000) {
      border = Border.all(color: const Color(0xFFB145E9), width: 3);
      shadows = [
        BoxShadow(
          color: const Color(0xFFB145E9).withValues(alpha: 0.4),
          blurRadius: 8,
        ),
      ];
    } else if (xp >= 5000) {
      border = Border.all(color: const Color(0xFFFFD700), width: 3);
    } else if (xp >= 1000) {
      border = Border.all(color: p.primary, width: 2.5);
    } else {
      border = Border.all(color: p.border, width: 1.5);
    }

    if (isOnFire) {
      shadows.add(
        BoxShadow(
          color: Colors.orange.withValues(alpha: 0.4),
          blurRadius: 15,
          spreadRadius: 2,
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: border,
            boxShadow: shadows,
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: p.listRowAlt,
            backgroundImage: imageUrl.isNotEmpty
                ? CachedNetworkImageProvider(imageUrl)
                : null,
            child: imageUrl.isEmpty
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: radius * 0.8,
                    ),
                  )
                : null,
          ),
        ),
        if (isOnFire)
          Positioned(
            bottom: -2,
            right: -2,
            child: _statusIconBadge(LucideIcons.flame, Colors.orange),
          ),
        if (isVerified)
          Positioned(
            top: 0,
            right: 0,
            child: _statusIconBadge(LucideIcons.badgeCheck, p.primary),
          ),
      ],
    );
  }

  Widget _statusIconBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: QortColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(icon, size: radius * 0.45, color: color),
    );
  }
}
