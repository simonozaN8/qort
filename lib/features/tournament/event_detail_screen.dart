import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_mode_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tournament_detail_screen.dart';
import '../../core/widgets/stock_image_attribution.dart';
import '../admin/tournament_composer_widget.dart';
import '../../core/services/event_sponsor_service.dart';
import '../admin/tournament_sponsor_band.dart';

/// Varžybų lygio prioritetas sąrašui (žemiausias → aukščiausias).
const _levelOrder = {
  'LIGHT': 1,
  'MIDDLE': 2,
  'HARD': 3,
  'PRO': 4,
  'ELITE': 5,
  'D': 1,
  'D/C': 2,
  'C/B': 3,
  'B/A': 4,
  'A': 5,
  'MĖGĖJAI': 1,
  'PAŽENGĘ': 2,
  'START': 1,
  'PRADEDANTYS': 1,
};

int _getLevelPriority(String name, String eventName) {
  var stripped = name;
  if (eventName.isNotEmpty && stripped.startsWith('$eventName - ')) {
    stripped = stripped.replaceFirst('$eventName - ', '');
  }
  stripped = stripped.toUpperCase().trim();
  return _levelOrder[stripped] ?? 99;
}

void _sortDivisionsByLevel(List<dynamic> divisions, String eventName) {
  divisions.sort((a, b) {
    final aName = a is Map ? a['name']?.toString() ?? '' : '';
    final bName = b is Map ? b['name']?.toString() ?? '' : '';
    return _getLevelPriority(aName, eventName)
        .compareTo(_getLevelPriority(bName, eventName));
  });
}

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoading = true;
  List<dynamic> _divisions = [];
  Map<String, dynamic>? _event;
  List<EventSponsor> _eventSponsors = [];

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  double? _getEventEntryPrice() {
    final list = _divisions;
    if (list.isEmpty) return null;
    final first = list.first;
    if (first is Map && first['entry_fee'] != null) {
      return (first['entry_fee'] as num).toDouble();
    }
    return null;
  }

  (EventSponsor?, List<EventSponsor>) _sponsorsForPreview() {
    final mainList = _eventSponsors.where((s) => s.isMain).toList();
    final EventSponsor? main = mainList.isNotEmpty ? mainList.first : null;
    final extras = _eventSponsors.where((s) => !s.isMain).toList();
    return (main, extras);
  }

  Future<void> _loadEvent() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final eventId = widget.event['id'];
      final fresh = await client
          .from('events')
          .select('*, tournaments(*), event_sponsors(*)')
          .eq('id', eventId)
          .single();

      final tournaments = (fresh['tournaments'] as List?) ?? const [];
      final sponsorsRaw = (fresh['event_sponsors'] as List?) ?? const [];
      final sponsors = sponsorsRaw
          .whereType<Map>()
          .map((j) => EventSponsor.fromJson(Map<String, dynamic>.from(j)))
          .toList();

      if (mounted) {
        final eventMap = Map<String, dynamic>.from(fresh as Map);
        final sortedDivisions = List<dynamic>.from(tournaments);
        _sortDivisionsByLevel(
          sortedDivisions,
          eventMap['name']?.toString() ?? '',
        );
        setState(() {
          _event = eventMap;
          _divisions = sortedDivisions;
          _eventSponsors = sponsors;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '—';
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw.toString();
    }
  }

  Future<void> _launchUri(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Nepavyko atidaryti: $uri, $e');
    }
  }

  Widget _infoRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: QortModeColors.competition, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ],
    );
  }

  Widget _infoRowClickable({
    required IconData icon,
    required String text,
    required double indent,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: QortModeColors.competition, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventInfoCard(Map<String, dynamic> e) {
    final email = e['organizer_email']?.toString().trim();
    final phone = e['organizer_phone']?.toString().trim();
    final organizer = e['organizer']?.toString().trim();
    final sport = e['sport']?.toString().trim();
    final location = e['location']?.toString().trim();
    final price = _getEventEntryPrice();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sport != null && sport.isNotEmpty) ...[
            _infoRow(
              icon: LucideIcons.trophy,
              text: 'Sportas: $sport',
            ),
            const SizedBox(height: 12),
          ],
          _infoRow(
            icon: LucideIcons.mapPin,
            text: location != null && location.isNotEmpty
                ? 'Vieta: $location'
                : 'Vieta: Nenurodyta',
          ),
          const SizedBox(height: 12),
          _infoRow(
            icon: LucideIcons.calendar,
            text:
                'Data: ${_formatDate(e['start_date'])} → ${_formatDate(e['end_date'])}',
          ),
          if (price != null && price > 0) ...[
            const SizedBox(height: 12),
            _infoRow(
              icon: LucideIcons.banknote,
              text: 'Dalyvio mokestis: ${price.toStringAsFixed(0)} €',
            ),
          ],
          const SizedBox(height: 12),
          _infoRow(
            icon: LucideIcons.user,
            text:
                'Organizatorius: ${organizer != null && organizer.isNotEmpty ? organizer : 'Nenurodyta'}',
          ),
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRowClickable(
              icon: LucideIcons.mail,
              text: email,
              indent: 28,
              onTap: () => _launchUri(Uri.parse('mailto:$email')),
            ),
          ],
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRowClickable(
              icon: LucideIcons.phone,
              text: phone,
              indent: 28,
              onTap: () => _launchUri(Uri.parse('tel:$phone')),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _event ?? widget.event;

    return Scaffold(
      backgroundColor: QortColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: QortColors.surface,
            iconTheme: const IconThemeData(color: QortColors.textPrimary),
            flexibleSpace: FlexibleSpaceBar(
              background: ClipRect(
                child: TournamentComposerWidget(
                  headerOnly: true,
                  imageUrl: e['image_url']?.toString(),
                  eventName: e['name']?.toString() ?? '',
                  sport: e['sport']?.toString() ?? '',
                  flipHorizontal: e['image_flip_horizontal'] == true,
                  colorFilterPreset: e['cover_filter_preset']?.toString(),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: TournamentSponsorBand(
              compact: false,
              mainSponsor: _sponsorsForPreview().$1,
              extraSponsors: _sponsorsForPreview().$2,
            ),
          ),

          SliverToBoxAdapter(
            child: StockImageAttribution(data: e),
          ),

          SliverToBoxAdapter(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(50),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: QortModeColors.competition,
                      ),
                    ),
                  )
                : _buildEventInfoCard(e),
          ),

          SliverToBoxAdapter(
            child: _isLoading
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e['description'] != null &&
                            e['description'].toString().isNotEmpty) ...[
                          Text(
                            "APIE RENGINĮ",
                            style: GoogleFonts.oswald(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            e['description'],
                            style: const TextStyle(
                              color: QortColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 25),
                        ],
                        Text(
                          "PASIRINKITE LYGĮ / KATEGORIJĄ",
                          style: GoogleFonts.bebasNeue(
                            color: QortColors.textPrimary,
                            fontSize: 26,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          "Spauskite ant norimos kategorijos, kad pamatytumėte detales ir registruotumėtės.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 20),
                        if (_divisions.isEmpty)
                          const Center(
                            child: Text(
                              "Kategorijų dar nėra.",
                              style: TextStyle(color: QortColors.textSecondary),
                            ),
                          ),
                        ..._divisions.map((div) {
                          String divName =
                              div['name']?.toString() ?? "Kategorija";
                          if (e['name'] != null &&
                              divName.startsWith(e['name'])) {
                            divName = divName
                                .replaceFirst("${e['name']} - ", "")
                                .trim();
                          }

                          int price = (div['entry_fee'] ?? 0).toInt();

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TournamentDetailScreen(tournament: div),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: QortColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: QortModeColors.competition
                                      .withValues(alpha: 0.5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: QortModeColors.competition
                                        .withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        divName.toUpperCase(),
                                        style: GoogleFonts.oswald(
                                          color: QortColors.textPrimary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            LucideIcons.users,
                                            color: QortModeColors.competition,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            "${div['gender_category'] ?? 'Atvira'} • ${div['team_format'] ?? '1v1'}",
                                            style: const TextStyle(
                                              color: QortColors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        price > 0 ? "$price €" : "NEMOKAMA",
                                        style: GoogleFonts.bebasNeue(
                                          color: Colors.greenAccent,
                                          fontSize: 20,
                                        ),
                                      ),
                                      const Icon(
                                        LucideIcons.chevronRight,
                                        color: QortColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
