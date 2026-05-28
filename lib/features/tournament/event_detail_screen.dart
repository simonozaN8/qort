import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// IMPORTUOJAME TAVO ORIGINALŲ TURNYRO VIDŲ
import 'tournament_detail_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoading = true;
  List<dynamic> _divisions = []; // Čia bus tavo "Light, Middle, Hard"

  @override
  void initState() {
    super.initState();
    _loadDivisions();
  }

  Future<void> _loadDivisions() async {
    setState(() => _isLoading = true);
    try {
      // Traukiame visus TURNYRUS, kurie priklauso šiam RENGINIUI
      final response = await Supabase.instance.client
          .from('tournaments')
          .select()
          .eq('event_id', widget.event['id'])
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _divisions = response;
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
    final e = widget.event;
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
              background: e['image_url'] != null
                  ? Image.network(e['image_url'], fit: BoxFit.cover)
                  : Container(
                      color: QortColors.border,
                      child: const Icon(
                        LucideIcons.image,
                        size: 50,
                        color: QortColors.navInactive,
                      ),
                    ),
              title: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  e['name'] ?? "Renginys",
                  style: GoogleFonts.bebasNeue(
                    color: QortColors.textPrimary,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
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
