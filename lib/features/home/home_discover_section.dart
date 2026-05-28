import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/qort_palette_extension.dart';
import '../../core/utils/sport_icons.dart';
import '../profile/user_model.dart';
import '../tournament/event_detail_screen.dart';
import '../tournament/tournament_detail_screen.dart';

/// Vieši turnyrai / renginiai — naujiems vartotojams ir tuščiai būsenai.
class HomeDiscoverSection extends StatelessWidget {
  final List<dynamic> events;
  final bool isLoading;
  final VoidCallback? onSeeAll;

  const HomeDiscoverSection({
    super.key,
    required this.events,
    this.isLoading = false,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    const accent = Color(0xFF3B82F6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'ATVIRI TURNYRAI',
                style: GoogleFonts.oswald(
                  color: p.textSecondary,
                  fontSize: 12,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                child: const Text(
                  'Žiūrėti visus',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: p.primary),
            ),
          )
        else if (events.isEmpty)
          _emptyHint(context)
        else
          ...events.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DiscoverEventCard(
                  event: Map<String, dynamic>.from(e as Map),
                ),
              )),
      ],
    );
  }

  Widget _emptyHint(BuildContext context) {
    final p = context.qortPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Text(
        'Šiuo metu viešų turnyrų nėra. Patikrinkite vėliau arba susisiekite su organizatoriumi.',
        textAlign: TextAlign.center,
        style: TextStyle(color: p.textSecondary, fontSize: 12, height: 1.4),
      ),
    );
  }
}

/// „Pradėk čia“ blokas — aktyvi tuščia būsena.
class HomeStartHereCard extends StatelessWidget {
  final AppMode mode;
  final VoidCallback? onOpenPlayTab;
  final VoidCallback? onOpenQuickActions;

  const HomeStartHereCard({
    super.key,
    required this.mode,
    this.onOpenPlayTab,
    this.onOpenQuickActions,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final copy = _copyForMode(mode);
    final accent = _accentForMode(mode);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(copy.icon, color: accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  copy.title,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            copy.body,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          if (onOpenPlayTab != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenPlayTab,
                icon: const Icon(LucideIcons.compass, size: 18),
                label: Text(copy.primaryCta),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          if (onOpenQuickActions != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenQuickActions,
                icon: Icon(LucideIcons.plus, size: 16, color: accent),
                label: Text(
                  'Užfiksuoti rezultatą (+)',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoverEventCard extends StatelessWidget {
  final Map<String, dynamic> event;

  const _DiscoverEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final isParent = event['is_parent_event'] == true;
    final sport = event['sport']?.toString() ?? 'Sportas';
    final name = event['name']?.toString() ?? 'Turnyras';
    final location = event['location']?.toString() ?? 'Vieta nenurodyta';

    String dateLabel = 'Data TBA';
    if (event['start_date'] != null) {
      try {
        final start = DateTime.parse(event['start_date'].toString());
        dateLabel = DateFormat('yyyy-MM-dd').format(start);
      } catch (_) {}
    }

    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openDetail(context, isParent),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    children: [
                      SportIcons.badge(sport, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$dateLabel · $location',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isParent ? 'Renginys' : 'Turnyras',
                              style: TextStyle(
                                color: p.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color: p.textSecondary.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, bool isParent) {
    if (isParent) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TournamentDetailScreen(tournament: event),
        ),
      );
    }
  }
}

class _StartCopy {
  final IconData icon;
  final String title;
  final String body;
  final String primaryCta;

  const _StartCopy(this.icon, this.title, this.body, this.primaryCta);
}

_StartCopy _copyForMode(AppMode mode) {
  switch (mode) {
    case AppMode.training:
      return const _StartCopy(
        LucideIcons.target,
        'Pradėk treniruotes',
        'Atidaryk skelbimų lentą, rask varžovą savo lygiu arba paskelbk atvirą mačą.',
        'Atidaryti skelbimus',
      );
    case AppMode.blitz:
      return const _StartCopy(
        LucideIcons.zap,
        'Įjunk Blitz',
        'Greiti mačai ir XP — eik į Blitz skiltį ir rask varžovą dabar.',
        'Eiti į Blitz',
      );
    case AppMode.competition:
    default:
      return const _StartCopy(
        LucideIcons.trophy,
        'Pradėk QORT kelionę',
        'Prisijunk prie turnyro, suplanuok mačą arba užfiksuok rezultatą. '
        'Žemiau — artimiausi atviri turnyrai.',
        'Žiūrėti turnyrus',
      );
  }
}

Color _accentForMode(AppMode mode) {
  switch (mode) {
    case AppMode.training:
      return const Color(0xFF16C56E);
    case AppMode.blitz:
      return const Color(0xFFD946EF);
    case AppMode.competition:
    default:
      return const Color(0xFF3B82F6);
  }
}
