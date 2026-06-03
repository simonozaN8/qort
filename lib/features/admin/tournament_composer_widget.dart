import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/services/event_sponsor_service.dart';
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
  final String? description;
  final String? organizerName;
  final List<TournamentLevelInfo> levels;
  final EventSponsor? mainSponsor;
  final List<EventSponsor> extraSponsors;
  final String? qrUrl;
  final double qrSize;
  final bool compact;
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
    this.description,
    this.organizerName,
    this.levels = const [],
    this.mainSponsor,
    this.extraSponsors = const [],
    this.qrUrl,
    this.qrSize = 72,
    this.compact = false,
    this.flipHorizontal = false,
    this.colorFilterPreset,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
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
            Positioned.fill(
              child: DecoratedBox(
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
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Text(
                'QORT',
                style: TextStyle(
                  fontFamily: 'Anton',
                  fontSize: compact ? 20 : 32,
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
              ),
            ),
            Positioned(
              left: 16,
              right: qrUrl != null && qrUrl!.isNotEmpty ? 100 : 16,
              bottom: compact ? 10 : 12,
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          eventName.toUpperCase(),
                          style: GoogleFonts.anton(
                            color: Colors.white,
                            fontSize: compact ? 18 : 28,
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
                        const SizedBox(height: 8),
                        _buildMetaRow(),
                        if (levels.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildLevelChips(),
                        ],
                      ],
                    )
                  : FittedBox(
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
                    ),
            ),
            if (qrUrl != null && qrUrl!.isNotEmpty)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(
                        data: qrUrl!,
                        size: qrSize,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'SKENUOK',
                        style: TextStyle(
                          fontFamily: 'Anton',
                          fontSize: 10,
                          color: Colors.black87,
                          letterSpacing: 1.5,
                          height: 1.0,
                        ),
                      ),
                      const Text(
                        'registruokis',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.black54,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildMetaRow() {
    final parts = <String>[];
    if (startDate != null && endDate != null) {
      parts.add('${_fmt(startDate!)} → ${_fmt(endDate!)}');
    } else if (startDate != null) {
      parts.add(_fmt(startDate!));
    }
    if (price != null && price! > 0) {
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

  Widget _buildLevelChips() {
    if (compact) {
      final visibleLevels = levels.take(6).toList();
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
