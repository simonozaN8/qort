import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/services/event_sponsor_service.dart';
import '../../core/services/pricing_tier_service.dart';
import '../../core/widgets/pricing_tier_display.dart';
import '../../core/widgets/tournament_cover_color_filters.dart';

/// 16:9 turnyro plakato peržiūra su QORT overlay (logo + info).
class TournamentComposerWidget extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;
  final Uint8List? imageBytes;
  final String eventName;
  final String sport;
  final String? location;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? price;
  final List<PricingTier>? pricingTiers;
  final String? description;
  final String? organizerName;
  final DateTime? registrationDeadline;
  final int? participantsCount;
  final List<TournamentLevelInfo> levels;
  final EventSponsor? mainSponsor;
  final List<EventSponsor> extraSponsors;
  final bool compact;
  final bool headerOnly;
  final bool flipHorizontal;
  final String? colorFilterPreset;

  const TournamentComposerWidget({
    super.key,
    this.imageUrl,
    this.imageFile,
    this.imageBytes,
    required this.eventName,
    required this.sport,
    this.location,
    this.startDate,
    this.endDate,
    this.price,
    this.pricingTiers,
    this.description,
    this.organizerName,
    this.registrationDeadline,
    this.participantsCount,
    this.levels = const [],
    this.mainSponsor,
    this.extraSponsors = const [],
    this.compact = false,
    this.headerOnly = false,
    this.flipHorizontal = false,
    this.colorFilterPreset,
  });

  @override
  Widget build(BuildContext context) {
    // Sąraše (compact): aspectRatio = width/height — platus stačiakampis (~16:10).
    final ratio = compact ? (16 / 10) : (16 / 9);
    return AspectRatio(
      aspectRatio: ratio,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBaseImage(),
            Positioned.fill(child: _buildGradient()),
            Positioned(top: 12, right: 12, child: _buildQortLogo()),
            if (headerOnly)
              Positioned(
                left: 16,
                right: 16,
                bottom: compact ? 10 : 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      eventName.toUpperCase(),
                      style: GoogleFonts.anton(
                        color: Colors.white,
                        fontSize: compact ? 18 : 32,
                        letterSpacing: 1.2,
                        height: 1.0,
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          sport,
                          if (location != null && location!.trim().isNotEmpty)
                            location!.trim(),
                        ].join(' · '),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              )
            else
              Positioned(
                left: 16,
                right: 16,
                bottom: compact ? 10 : 12,
                child: _buildOverlayContent(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBaseImage() {
    Widget img;
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      img = Image.memory(imageBytes!, fit: BoxFit.cover);
    } else if (imageFile != null && !kIsWeb) {
      img = Image.file(imageFile!, fit: BoxFit.cover);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      img = CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover);
    } else {
      img = Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(
          child: Icon(Icons.image_outlined, color: Colors.white24, size: 80),
        ),
      );
    }

    if (flipHorizontal) {
      img = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
        child: img,
      );
    }

    final filter = TournamentCoverColorFilters.filterForPreset(colorFilterPreset);
    if (filter != null) {
      img = ColorFiltered(colorFilter: filter, child: img);
    }
    return img;
  }

  Widget _buildGradient() {
    if (headerOnly) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.35),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
            Colors.black.withValues(alpha: 0.95),
          ],
          stops: const [0.0, 0.2, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildQortLogo() {
    return Text(
      'QORT',
      style: TextStyle(
        fontFamily: 'Anton',
        fontSize: (headerOnly && compact)
            ? 20
            : (headerOnly ? 32 : (compact ? 20 : 32)),
        color: const Color(0xFFEAB308),
        letterSpacing: 2,
        height: 1,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayContent() {
    if (compact) {
      return _buildCompactOverlayContent();
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            eventName.toUpperCase(),
            style: GoogleFonts.anton(
              color: Colors.white,
              fontSize: 28,
              letterSpacing: 1.2,
              height: 1.0,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            [
              sport,
              if (location != null && location!.trim().isNotEmpty)
                location!.trim(),
            ].join(' · '),
            style: const TextStyle(
              color: Color(0xFFEAB308),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if ((description?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 4),
            Text(
              description!.trim(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          _buildMetaRow(),
          _buildPriceSection(),
          if (levels.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildLevelChips(),
          ],
          if ((organizerName?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Text(
              'Organizatorius: ${organizerName!.trim()}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactOverlayContent() {
    final dateText = _formatDateRange(startDate, endDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eventName.toUpperCase(),
          style: GoogleFonts.anton(
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 1.2,
            height: 1.0,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          [
            sport,
            if (location != null && location!.trim().isNotEmpty)
              location!.trim(),
          ].join(' · '),
          style: const TextStyle(
            color: Color(0xFFEAB308),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (dateText.isNotEmpty)
          _compactInfoRow(icon: LucideIcons.calendar, text: dateText),
        if (registrationDeadline != null)
          _compactInfoRow(
            icon: LucideIcons.clock,
            text: 'Registracija iki ${_formatDate(registrationDeadline)}',
          ),
        _buildCompactPricingRows(),
        if (organizerName != null && organizerName!.trim().isNotEmpty)
          _compactInfoRow(
            icon: LucideIcons.user,
            text: organizerName!.trim(),
          ),
        _compactInfoRow(
          icon: LucideIcons.users,
          text: '${participantsCount ?? 0} dalyvių',
        ),
        if (levels.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildLevelChips(),
        ],
      ],
    );
  }

  Widget _compactInfoRow({
    required IconData icon,
    required String text,
    Color? iconColor,
    Color? textColor,
    FontWeight? fontWeight,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor ?? const Color(0xFFEAB308),
            size: 12,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor ?? Colors.white70,
                fontSize: 11,
                fontWeight: fontWeight,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPricingRows() {
    final visibleTiers = _displayTiers();
    if (visibleTiers.isEmpty) return const SizedBox.shrink();

    final effectiveTier = PricingTierService.getEffectiveTier(visibleTiers);

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
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            children: [
              Icon(
                isActive
                    ? LucideIcons.flame
                    : (tier.validUntil != null
                        ? LucideIcons.clock
                        : LucideIcons.banknote),
                color: isActive ? Colors.green : Colors.white54,
                size: 12,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatTierLabel(tier),
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.white54,
                    fontSize: 11,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null) return '';

    final startStr = _formatDate(start);

    if (end == null || _isSameDay(start, end)) {
      return startStr;
    }

    return '$startStr → ${_formatDate(end)}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(dynamic raw) {
    if (raw is DateTime) {
      return '${raw.year}-${raw.month.toString().padLeft(2, '0')}-${raw.day.toString().padLeft(2, '0')}';
    }
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatTierLabel(PricingTier tier) {
    final price = tier.price.toStringAsFixed(0);

    if (tier.validUntil == null) {
      return '${tier.name}: $price€';
    }

    final daysLeft = tier.validUntil!.difference(DateTime.now()).inDays;

    final String dayText;
    if (daysLeft <= 0) {
      dayText = 'paskutinė diena!';
    } else if (daysLeft == 1) {
      dayText = 'liko 1 d.';
    } else {
      dayText = 'liko $daysLeft d.';
    }

    return '${tier.name}: $price€ ($dayText)';
  }

  /// Dalyvių skaičius iš event lygio arba sumuojant per turnyrus.
  static int resolveParticipantsCount(Map<String, dynamic> event) {
    final eventCount = (event['participants_count'] as num?)?.toInt();
    if (eventCount != null) return eventCount;

    var total = 0;
    final tournaments = event['tournaments'] as List? ?? [];
    for (final t in tournaments) {
      if (t is! Map) continue;
      final tpList = t['tournament_participants'] as List? ?? [];
      if (tpList.isNotEmpty) {
        final first = tpList.first;
        if (first is Map) {
          total += (first['count'] as num?)?.toInt() ?? 0;
        }
      }
    }
    return total;
  }

  List<PricingTier> _effectiveTiers() {
    if (pricingTiers != null) {
      return pricingTiers!;
    }
    if (price != null && price! > 0) {
      return [
        PricingTier(
          id: '',
          eventId: '',
          name: 'Įprasta',
          price: price!,
          displayOrder: 0,
        ),
      ];
    }
    return [];
  }

  Widget _buildMetaRow() {
    final parts = <String>[];
    if (startDate != null && endDate != null) {
      parts.add('${_fmt(startDate!)} → ${_fmt(endDate!)}');
    } else if (startDate != null) {
      parts.add(_fmt(startDate!));
    }
    final tiers = _effectiveTiers();
    final effective = PricingTierService.getEffectiveTier(tiers);
    if (effective != null && effective.price > 0) {
      parts.add('${effective.price.toStringAsFixed(0)}€');
    } else if (price != null && price! > 0) {
      parts.add('${price!.toStringAsFixed(0)}€');
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  ·  '),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildPriceSection() {
    if (compact) return const SizedBox.shrink();

    final tiers = _displayTiers();
    if (tiers.length <= 1) return const SizedBox.shrink();

    final fontSize = compact ? 10.0 : 12.0;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: PricingTierDisplay(
          tiers: tiers,
          compact: false,
          onDarkBackground: true,
          baseStyle: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Compact sąraše — nerodyti pasibaigusių pakopų; su validUntil pirma.
  List<PricingTier> _displayTiers() {
    final tiers = _effectiveTiers();
    if (!compact) return tiers;

    final now = DateTime.now();
    final visible = tiers
        .where((t) => t.validUntil == null || t.validUntil!.isAfter(now))
        .toList();

    visible.sort((a, b) {
      if (a.validUntil == null) return 1;
      if (b.validUntil == null) return -1;
      return a.validUntil!.compareTo(b.validUntil!);
    });

    return visible;
  }

  Widget _buildLevelChips() {
    if (compact) {
      final visibleLevels = levels.take(2).toList();
      final hiddenCount = levels.length - visibleLevels.length;

      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          ...visibleLevels.map((l) => _buildLevelChip(l)),
          if (hiddenCount > 0) _buildMoreBadge(hiddenCount),
        ],
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: levels.map((l) => _buildLevelChip(l)).toList(),
    );
  }

  Widget _buildLevelChip(TournamentLevelInfo level) {
    final text = level.displayText;
    final fontSize = compact && text.length > 25 ? 10.0 : 11.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.9),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildMoreBadge(int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '+$n',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}

class TournamentLevelInfo {
  final String levelName;
  final String formatCode;
  final String? gender;
  final int? minRp;
  final int? maxRp;

  const TournamentLevelInfo({
    required this.levelName,
    required this.formatCode,
    this.gender,
    this.minRp,
    this.maxRp,
  });

  static String stripEventPrefix({
    required String tournamentName,
    required String eventName,
  }) {
    final prefix = '${eventName.trim()} - ';
    if (tournamentName.startsWith(prefix)) {
      return tournamentName.replaceFirst(prefix, '');
    }
    return tournamentName;
  }

  static String? translateGender(String? raw) {
    if (raw == null) return null;
    final v = raw.trim();
    if (v.isEmpty) return null;
    final low = v.toLowerCase();
    if (low == 'mix' || low == 'visi') return null;
    if (low == 'men' || low == 'vyrai') return 'Vyrai';
    if (low == 'women' || low == 'moterys') return 'Moterys';
    return v;
  }

  String get displayText {
    final parts = <String>[];
    parts.add(levelName.toUpperCase());

    final mid = <String>[];
    final g = translateGender(gender);
    if (g != null) mid.add(g);
    mid.add(formatCode);
    parts.add(mid.join(' '));

    final min = minRp ?? 0;
    final max = maxRp ?? 3000;
    if (!(min == 0 && max == 3000)) {
      parts.add('$min-$max RP');
    }

    return parts.join(' · ');
  }
}
