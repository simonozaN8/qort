import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sporto šakos vizualinis identitetas — spalva + atpažįstama ikona.
enum SportVisualKind {
  tennis,
  padel,
  pickleball,
  badminton,
  squash,
  tableTennis,
  basketball,
  football,
  volleyball,
  beach,
  handball,
  darts,
  bowling,
  billiards,
  paintball,
  generic,
}

class SportVisualSpec {
  final SportVisualKind kind;
  final IconData icon;
  final Color primary;
  final Color secondary;
  final String emoji;

  const SportVisualSpec({
    required this.kind,
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.emoji,
  });
}

/// Vaizdinės sporto ikonos — ne abstraktūs Lucide simboliai.
class SportVisualIcon {
  SportVisualIcon._();

  static SportVisualSpec specFor(String sportName, {String? iconName}) {
    if (iconName != null && iconName.isNotEmpty) {
      final byKey = _byIconName(iconName);
      if (byKey != null) return byKey;
    }
    return _bySportName(sportName);
  }

  static IconData forSport(String sportName, {String? iconName}) =>
      specFor(sportName, iconName: iconName).icon;

  static Widget badge(
    String sportName, {
    String? iconName,
    double size = 36,
    bool showEmoji = false,
  }) {
    final spec = specFor(sportName, iconName: iconName);
    return _SportIconBadge(spec: spec, size: size, showEmoji: showEmoji);
  }

  static Widget icon(
    String sportName, {
    String? iconName,
    double size = 20,
    Color? color,
  }) {
    final spec = specFor(sportName, iconName: iconName);
    return Icon(
      spec.icon,
      size: size,
      color: color ?? spec.primary,
    );
  }

  static SportVisualSpec? _byIconName(String iconName) {
    switch (iconName) {
      case 'tennis':
      case 'activity':
        return _tennis;
      case 'trophy':
        return _generic;
      case 'target':
        return _pickleball;
      case 'feather':
        return _badminton;
      case 'circle-dot':
        return _bowling;
      case 'table':
        return _tableTennis;
      case 'volleyball':
        return _volleyball;
      case 'sun':
        return _beach;
      case 'aperture':
        return _billiards;
      case 'crosshair':
        return _darts;
      case 'layout-grid':
        return _padel;
      case 'dribbble':
        return _basketball;
      case 'goal':
        return _football;
      case 'hand':
        return _handball;
      default:
        return null;
    }
  }

  static SportVisualSpec _bySportName(String name) {
    final n = name.trim().toLowerCase();

    if (n.contains('tenis') && !n.contains('stalo')) return _tennis;
    if (n.contains('padel')) return _padel;
    if (n.contains('pickle') || n.contains('pikl') || n.contains('pikli')) {
      return _pickleball;
    }
    if (n.contains('badminton')) return _badminton;
    if (n.contains('skvoš') || n.contains('squash')) return _squash;
    if (n.contains('stalo tenis')) return _tableTennis;
    if (n.contains('krepšin') || n.contains('basketball')) return _basketball;
    if (n.contains('futbol') || n.contains('football') || n.contains('soccer')) {
      return _football;
    }
    if (n.contains('paplūdim') || n.contains('beach')) return _beach;
    if (n.contains('tinklin') || n.contains('volley')) return _volleyball;
    if (n.contains('smigin') || n.contains('dart')) return _darts;
    if (n.contains('bouling') || n.contains('bowl')) return _bowling;
    if (n.contains('biliard') || n.contains('pool') || n.contains('snuker')) {
      return _billiards;
    }
    if (n.contains('dažasvy') || n.contains('paintball')) return _paintball;
    if (n.contains('rankin') || n.contains('handball')) return _handball;
    if (n == 'visi') return _generic;

    return _generic;
  }

  static const _tennis = SportVisualSpec(
    kind: SportVisualKind.tennis,
    icon: Icons.sports_tennis,
    primary: Color(0xFF84CC16),
    secondary: Color(0xFFECFCCB),
    emoji: '🎾',
  );

  static const _padel = SportVisualSpec(
    kind: SportVisualKind.padel,
    icon: Icons.sports_tennis,
    primary: Color(0xFF0EA5E9),
    secondary: Color(0xFFE0F2FE),
    emoji: '🏸',
  );

  static const _pickleball = SportVisualSpec(
    kind: SportVisualKind.pickleball,
    icon: Icons.sports_baseball,
    primary: Color(0xFFF59E0B),
    secondary: Color(0xFFFEF3C7),
    emoji: '🏓',
  );

  static const _badminton = SportVisualSpec(
    kind: SportVisualKind.badminton,
    icon: Icons.sports_martial_arts,
    primary: Color(0xFFEAB308),
    secondary: Color(0xFFFEF9C3),
    emoji: '🏸',
  );

  static const _squash = SportVisualSpec(
    kind: SportVisualKind.squash,
    icon: Icons.sports_tennis,
    primary: Color(0xFFEF4444),
    secondary: Color(0xFFFEE2E2),
    emoji: '🎯',
  );

  static const _tableTennis = SportVisualSpec(
    kind: SportVisualKind.tableTennis,
    icon: Icons.sports_esports,
    primary: Color(0xFF6366F1),
    secondary: Color(0xFFE0E7FF),
    emoji: '🏓',
  );

  static const _basketball = SportVisualSpec(
    kind: SportVisualKind.basketball,
    icon: Icons.sports_basketball,
    primary: Color(0xFFF97316),
    secondary: Color(0xFFFFEDD5),
    emoji: '🏀',
  );

  static const _football = SportVisualSpec(
    kind: SportVisualKind.football,
    icon: Icons.sports_soccer,
    primary: Color(0xFF22C55E),
    secondary: Color(0xFFDCFCE7),
    emoji: '⚽',
  );

  static const _volleyball = SportVisualSpec(
    kind: SportVisualKind.volleyball,
    icon: Icons.sports_volleyball,
    primary: Color(0xFF3B82F6),
    secondary: Color(0xFFDBEAFE),
    emoji: '🏐',
  );

  static const _beach = SportVisualSpec(
    kind: SportVisualKind.beach,
    icon: Icons.sports_volleyball,
    primary: Color(0xFFFBBF24),
    secondary: Color(0xFFFEF3C7),
    emoji: '🏖️',
  );

  static const _handball = SportVisualSpec(
    kind: SportVisualKind.handball,
    icon: Icons.sports_handball,
    primary: Color(0xFF8B5CF6),
    secondary: Color(0xFFEDE9FE),
    emoji: '🤾',
  );

  static const _darts = SportVisualSpec(
    kind: SportVisualKind.darts,
    icon: Icons.adjust,
    primary: Color(0xFFDC2626),
    secondary: Color(0xFFFEE2E2),
    emoji: '🎯',
  );

  static const _bowling = SportVisualSpec(
    kind: SportVisualKind.bowling,
    icon: Icons.sports,
    primary: Color(0xFF78716C),
    secondary: Color(0xFFF5F5F4),
    emoji: '🎳',
  );

  static const _billiards = SportVisualSpec(
    kind: SportVisualKind.billiards,
    icon: Icons.circle,
    primary: Color(0xFF059669),
    secondary: Color(0xFFD1FAE5),
    emoji: '🎱',
  );

  static const _paintball = SportVisualSpec(
    kind: SportVisualKind.paintball,
    icon: Icons.water_drop,
    primary: Color(0xFFEC4899),
    secondary: Color(0xFFFCE7F3),
    emoji: '💥',
  );

  static const _generic = SportVisualSpec(
    kind: SportVisualKind.generic,
    icon: LucideIcons.medal,
    primary: Color(0xFF64748B),
    secondary: Color(0xFFF1F5F9),
    emoji: '🏅',
  );
}

class _SportIconBadge extends StatelessWidget {
  final SportVisualSpec spec;
  final double size;
  final bool showEmoji;

  const _SportIconBadge({
    required this.spec,
    required this.size,
    required this.showEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.52;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            spec.secondary,
            spec.primary.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: spec.primary.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: spec.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: showEmoji && spec.emoji.isNotEmpty
          ? Center(
              child: Text(spec.emoji, style: TextStyle(fontSize: iconSize)),
            )
          : Icon(spec.icon, color: spec.primary, size: iconSize),
    );
  }
}

/// Senesnis API — deleguoja į [SportVisualIcon].
class SportIcons {
  SportIcons._();

  static IconData forSport(String sportName, {String? iconName}) =>
      SportVisualIcon.forSport(sportName, iconName: iconName);

  static Widget icon(
    String sportName, {
    String? iconName,
    double size = 18,
    Color? color,
  }) =>
      SportVisualIcon.icon(
        sportName,
        iconName: iconName,
        size: size,
        color: color,
      );

  static Widget badge(
    String sportName, {
    String? iconName,
    double size = 36,
    bool showEmoji = false,
  }) =>
      SportVisualIcon.badge(
        sportName,
        iconName: iconName,
        size: size,
        showEmoji: showEmoji,
      );
}
