import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// IMPORTUOJAME TAVO ORIGINALŲ TURNYRO VIDŲ
import 'tournament_detail_screen.dart';
import '../../core/widgets/stock_image_attribution.dart';
import '../admin/tournament_composer_widget.dart';
import '../../core/services/event_sponsor_service.dart';
import '../admin/tournament_sponsor_band.dart';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoading = true;
  List<dynamic> _divisions = []; // Čia bus tavo "Light, Middle, Hard"
  Map<String, dynamic>? _event;
  List<EventSponsor> _eventSponsors = [];

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  double? _getEventEntryPrice() {
    // event-level poster: use first tournament's entry_fee if present
    final list = _divisions;
    if (list.isEmpty) return null;
    final first = list.first;
    if (first is Map && first['entry_fee'] != null) {
      return (first['entry_fee'] as num).toDouble();
    }
    return null;
  }

  List<TournamentLevelInfo> _levelsForPreview() {
    final e = _event ?? widget.event;
    final evName = e['name']?.toString() ?? '';
    return _divisions.whereType<Map>().map((t) {
      final tName = t['name']?.toString() ?? '';
      final level = TournamentLevelInfo.stripEventPrefix(
        tournamentName: tName,
        eventName: evName,
      );
      return TournamentLevelInfo(
        levelName: level,
        formatCode: t['format_code']?.toString() ?? '1v1',
        gender: t['gender']?.toString(),
        minRp: (t['min_rp'] as num?)?.toInt() ?? 0,
        maxRp: (t['max_rp'] as num?)?.toInt() ?? 3000,
      );
    }).toList();
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
        setState(() {
          _event = Map<String, dynamic>.from(fresh as Map);
          _divisions = tournaments;
          _eventSponsors = sponsors;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _event ?? widget.event;
    String startDate = e['start_date'] != null
        ? DateFormat('yyyy-MM-dd').format(DateTime.parse(e['start_date']))
        : '';
    String endDate = e['end_date'] != null
        ? DateFormat('yyyy-MM-dd').format(DateTime.parse(e['end_date']))
        : '';

    return Scaffold(
      backgroundColor: QortColors.background,
      body: CustomScrollView(
        slivers: [
          // PLAKATAS
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: QortColors.surface,
            iconTheme: const IconThemeData(color: QortColors.textPrimary),
            flexibleSpace: FlexibleSpaceBar(
              background: ClipRect(
                child: TournamentComposerWidget(
                  imageUrl: e['image_url']?.toString(),
                  eventName: e['name']?.toString() ?? '',
                  sport: e['sport']?.toString() ?? '',
                  location: e['location']?.toString(),
                  description: e['description']?.toString(),
                  organizerName: e['organizer']?.toString(),
                  startDate: _parseDate(e['start_date']),
                  endDate: _parseDate(e['end_date']),
                  levels: _levelsForPreview(),
                  price: _getEventEntryPrice(),
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

          // INFORMACIJA IR LYGIŲ PASIRINKIMAS
          SliverToBoxAdapter(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(50),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD946EF),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.mapPin,
                              color: Colors.blue,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e['location'] ?? "Vieta nenurodyta",
                                style: const TextStyle(
                                  color: QortColors.textPrimary,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.calendarClock,
                              color: Colors.orange,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "$startDate  -  $endDate",
                              style: const TextStyle(
                                color: QortColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),

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
                          // Pavadinimo sutvarkymas (nuimame tėvinį pavadinimą, jei jis užsilikęs)
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
                              // ATIDARO TAVO ORIGINALŲ TURNYRO EKRANĄ
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
                                  color: const Color(
                                    0xFFD946EF,
                                  ).withOpacity(0.5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFD946EF,
                                    ).withOpacity(0.1),
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
                                            color: Colors.blueAccent,
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
