import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/event_sponsor_service.dart';

class TournamentSponsorBand extends StatelessWidget {
  final EventSponsor? mainSponsor;
  final List<EventSponsor> extraSponsors;
  final bool compact; // True = sąrašui, false = full mode

  const TournamentSponsorBand({
    super.key,
    required this.mainSponsor,
    required this.extraSponsors,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (mainSponsor == null && extraSponsors.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleCount = compact ? 3 : 6;
    final visible = extraSponsors.take(visibleCount).toList();
    final remaining = extraSponsors.length - visible.length;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFEAB308).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            const Text(
              'RĖMĖJAI',
              style: TextStyle(
                fontFamily: 'Anton',
                fontSize: 11,
                letterSpacing: 1.5,
                color: Color(0xFFEAB308),
              ),
            ),
            const SizedBox(height: 6),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mainSponsor != null) ...[
                  _buildSponsor(mainSponsor!, isMain: true, compact: compact),
                  if (extraSponsors.isNotEmpty)
                    Container(
                      width: 1,
                      height: compact ? 24 : 36,
                      color: Colors.white24,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                ],
                ...visible.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildSponsor(s, isMain: false, compact: compact),
                  ),
                ),
                if (remaining > 0)
                  Text(
                    '+$remaining',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: compact ? 11 : 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSponsor(
    EventSponsor s, {
    required bool isMain,
    required bool compact,
  }) {
    final logoHeight =
        isMain ? (compact ? 28.0 : 50.0) : (compact ? 22.0 : 32.0);

    final logoWidget = Container(
      height: logoHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(4),
        border: isMain
            ? Border.all(color: const Color(0xFFEAB308), width: 1.5)
            : null,
      ),
      child: _logo(s),
    );

    final hasUrl = s.websiteUrl != null && s.websiteUrl!.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasUrl)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => _launchSponsorUrl(s.websiteUrl!),
              child: logoWidget,
            ),
          )
        else
          logoWidget,
        if (!compact && (s.sponsorLabel?.trim().isNotEmpty ?? false)) ...[
          const SizedBox(height: 3),
          Text(
            s.sponsorLabel!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _logo(EventSponsor s) {
    final bytes = s.logoBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(bytes, fit: BoxFit.contain);
    }
    return CachedNetworkImage(
      imageUrl: s.logoUrl,
      fit: BoxFit.contain,
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

Future<void> _launchSponsorUrl(String rawUrl) async {
  String url = rawUrl.trim();

  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'https://$url';
  }

  final uri = Uri.tryParse(url);
  if (uri == null) return;

  try {
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  } catch (e) {
    debugPrint('Nepavyko atidaryti URL: $url, klaida: $e');
  }
}
