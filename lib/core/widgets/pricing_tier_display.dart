import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/pricing_tier_service.dart';

/// Renginio kainų pakopų rodymas (viena ar kelios pakopos).
class PricingTierDisplay extends StatelessWidget {
  final List<PricingTier> tiers;
  final TextStyle? baseStyle;
  final bool compact;
  final bool onDarkBackground;

  const PricingTierDisplay({
    super.key,
    required this.tiers,
    this.baseStyle,
    this.compact = false,
    this.onDarkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    if (tiers.isEmpty) return const SizedBox.shrink();

    if (compact) {
      final current = PricingTierService.getEffectiveTier(tiers);
      if (current == null) {
        return Text(
          'Registracija uždaryta',
          style: baseStyle ??
              TextStyle(
                color: onDarkBackground ? Colors.white54 : Colors.black54,
                fontSize: 12,
              ),
        );
      }
      return Text(
        '${current.price.toStringAsFixed(0)} €',
        style: baseStyle ??
            TextStyle(
              color: onDarkBackground ? Colors.white : Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
      );
    }

    final now = DateTime.now();
    final visibleTiers = tiers
        .where((t) => t.validUntil == null || t.validUntil!.isAfter(now))
        .toList();

    if (visibleTiers.isEmpty) {
      return Text(
        'Registracija uždaryta',
        style: baseStyle ??
            TextStyle(
              color: onDarkBackground ? Colors.white54 : Colors.black54,
              fontSize: 12,
            ),
      );
    }

    visibleTiers.sort((a, b) {
      if (a.validUntil == null) return 1;
      if (b.validUntil == null) return -1;
      return a.validUntil!.compareTo(b.validUntil!);
    });

    final effectiveTier = PricingTierService.getEffectiveTier(visibleTiers);
    final fontSize = baseStyle?.fontSize ?? 13;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: visibleTiers.map((tier) {
        final isActive = effectiveTier != null &&
            (tier.id.isNotEmpty
                ? tier.id == effectiveTier.id
                : tier.displayOrder == effectiveTier.displayOrder &&
                    tier.name == effectiveTier.name);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive
                    ? LucideIcons.flame
                    : (tier.validUntil != null
                        ? LucideIcons.clock
                        : LucideIcons.banknote),
                color: isActive ? Colors.green : const Color(0xFFEAB308),
                size: 14,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _formatTier(tier),
                  style: TextStyle(
                    color: isActive ? Colors.green : const Color(0xFFEAB308),
                    fontSize: fontSize,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatTier(PricingTier tier) {
    final price = tier.price.toStringAsFixed(0);
    if (tier.validUntil == null) {
      return '${tier.name}: $price€';
    }
    final d = tier.validUntil!;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '${tier.name}: $price€ (iki $dateStr)';
  }
}

String formatPricingTierDate(DateTime dt) {
  return DateFormat('yyyy-MM-dd').format(dt);
}
