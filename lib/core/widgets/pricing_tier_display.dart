import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/pricing_tier_service.dart';
import '../theme/qort_colors.dart';
import '../theme/qort_mode_colors.dart';

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
    final current = PricingTierService.getEffectiveTier(tiers);
    if (current == null) {
      return Text(
        'Registracija uždaryta',
        style: baseStyle ?? const TextStyle(color: Colors.white70, fontSize: 12),
      );
    }

    if (compact || tiers.length <= 1) {
      return Text(
        '${current.price.toStringAsFixed(0)} €',
        style: baseStyle ??
            const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tiers.map((tier) => _buildTierRow(tier, current)).toList(),
    );
  }

  Widget _buildTierRow(PricingTier tier, PricingTier current) {
    final isCurrent = tier.id.isNotEmpty
        ? tier.id == current.id
        : tier.displayOrder == current.displayOrder && tier.name == current.name;
    final isExpired = tier.isExpired();
    final activeColor = onDarkBackground ? Colors.green : Colors.green.shade700;
    final expiredColor = onDarkBackground ? Colors.grey : QortColors.textSecondary;
    final pendingColor =
        onDarkBackground ? Colors.white54 : QortColors.textSecondary;
    final textActive = onDarkBackground ? Colors.green : Colors.green.shade700;
    final textNormal =
        onDarkBackground ? Colors.white70 : QortColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCurrent
                ? Icons.check_circle
                : isExpired
                    ? Icons.cancel
                    : Icons.schedule,
            color: isCurrent
                ? activeColor
                : isExpired
                    ? expiredColor
                    : pendingColor,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            '${tier.name}: ${tier.price.toStringAsFixed(0)} €',
            style: TextStyle(
              color: isCurrent
                  ? textActive
                  : isExpired
                      ? expiredColor
                      : textNormal,
              decoration: isExpired ? TextDecoration.lineThrough : null,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              fontSize: baseStyle?.fontSize ?? 12,
            ),
          ),
          if (isCurrent && tier.validUntil != null) ...[
            const SizedBox(width: 6),
            Text(
              _formatDaysLeft(tier.validUntil!),
              style: const TextStyle(
                color: QortModeColors.competition,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDaysLeft(DateTime until) {
    final days = until.difference(DateTime.now()).inDays;
    if (days < 0) return '';
    if (days == 0) return '(paskutinė diena!)';
    if (days <= 3) return '(liko $days d.)';
    return '(iki ${until.day}.${until.month})';
  }
}

String formatPricingTierDate(DateTime dt) {
  return DateFormat('yyyy-MM-dd').format(dt);
}
