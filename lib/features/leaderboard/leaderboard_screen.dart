import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/query_limits.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/models/sport_catalog_entry.dart';
import '../../core/services/sports_catalog_service.dart';
import '../../core/utils/sport_levels.dart';
import '../profile/user_model.dart';
import '../../core/utils/sport_icons.dart';

// Speciali klasė, skirta saugiai laikyti išfiltruotus reitingo duomenis
class LeaderboardEntry {
  final String id;
  final String name;
  final String photoUrl;
  final int level;
  final int rollingRp;
  final int globalRp;

  LeaderboardEntry({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.level,
    required this.rollingRp,
    required this.globalRp,
  });
}

class LeaderboardScreen extends StatefulWidget {
  final AppMode currentMode;
  const LeaderboardScreen({super.key, this.currentMode = AppMode.competition});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;

  // Sporto įrašai su profilio duomenimis (user_sports + profiles)
  List<dynamic> _sportRows = [];

  // Apdorotas ir surūšiuotas sąrašas, kurį rodome ekrane
  List<LeaderboardEntry> _rankedUsers = [];

  // Filtrai
  String _selectedScope = "GLOBALUS"; // "GLOBALUS" arba "MANO LYGIS"
  String _selectedSport = "Tenisas";
  int _selectedLevel = 1;

  List<String> _sportsList = ["Tenisas"];
  Map<String, SportCatalogEntry> _catalogBySport = {};

  @override
  void initState() {
    super.initState();
    _loadSportsThenLeaderboard();
  }

  Future<void> _loadSportsThenLeaderboard() async {
    try {
      final entries = await SportsCatalogService.fetchActive(force: true);
      if (mounted) {
        setState(() {
          _catalogBySport = {for (final e in entries) e.name: e};
          _sportsList = entries.map((e) => e.name).toList();
          if (_sportsList.isNotEmpty &&
              !_sportsList.contains(_selectedSport)) {
            _selectedSport = _sportsList.first;
          }
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant sportų katalogą: $e");
    }
    await _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      dynamic response;
      try {
        response = await client
            .from('user_sports')
            .select(
              'sport, level, official_rp, rp_history, user_id, '
              'profiles!inner(id, name, surname, nickname, photo_url)',
            )
            .limit(QueryLimits.leaderboardRows);
      } on PostgrestException catch (e) {
        if (e.code != '42703' || !e.message.contains('rp_history')) rethrow;
        response = await client
            .from('user_sports')
            .select(
              'sport, level, official_rp, user_id, '
              'profiles!inner(id, name, surname, nickname, photo_url)',
            )
            .limit(QueryLimits.leaderboardRows);
      }

      if (mounted) {
        setState(() {
          _sportRows = response;
          _processAndSortUsers();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant reitingus: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- MATEMATIKA IR RŪŠIAVIMAS ---

  int _getLevelMaxRp(int level) {
    switch (level) {
      case 1:
        return 1000;
      case 2:
        return 1500;
      case 3:
        return 2000;
      case 4:
        return 2500;
      case 5:
        return 3000;
      default:
        return 1000;
    }
  }

  int _calculateRollingRp(List<dynamic> history) {
    try {
      int activeRpDelta = 0;
      DateTime oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      int previousRp = 1000;

      for (var entry in history) {
        if (entry == null) continue;
        int entryRp = 1000;
        if (entry['rp'] != null) {
          entryRp = int.tryParse(entry['rp'].toString()) ?? previousRp;
        }

        DateTime entryDate = DateTime.now();
        if (entry['date'] != null) {
          entryDate =
              DateTime.tryParse(entry['date'].toString()) ?? DateTime.now();
        }

        int delta = entryRp - previousRp;
        if (entryDate.isAfter(oneYearAgo)) {
          activeRpDelta += delta;
        }
        previousRp = entryRp;
      }

      int finalRp = 1000 + activeRpDelta;
      return finalRp < 0 ? 0 : finalRp;
    } catch (e) {
      return 1000;
    }
  }

  int _calculateGlobalRp(int localRp, int level) {
    int maxRp = _getLevelMaxRp(level);
    return (localRp * (maxRp / 3000.0)).round();
  }

  void _processAndSortUsers() {
    List<LeaderboardEntry> tempList = [];

    for (var row in _sportRows) {
      try {
        final sportName = row['sport']?.toString() ?? '';
        if (sportName.toLowerCase() != _selectedSport.toLowerCase()) continue;

        final profile = row['profiles'];
        if (profile == null) continue;

        final level = int.tryParse(row['level']?.toString() ?? '1') ?? 1;
        final history = row['rp_history'] is List
            ? row['rp_history'] as List
            : <dynamic>[];

        final storedRp = (row['official_rp'] as num?)?.toInt();
        final rollingRp = storedRp ?? _calculateRollingRp(history);
        final globalRp = _calculateGlobalRp(rollingRp, level);

        String name = profile['name']?.toString() ?? '';
        String surname = profile['surname']?.toString() ?? '';
        String nick = profile['nickname']?.toString() ?? 'Žaidėjas';
        String fullName = "$name $surname".trim();
        if (fullName.isEmpty) fullName = nick;

        tempList.add(
          LeaderboardEntry(
            id: profile['id'].toString(),
            name: fullName,
            photoUrl: profile['photo_url']?.toString() ?? '',
            level: level,
            rollingRp: rollingRp,
            globalRp: globalRp,
          ),
        );
      } catch (e) {
        debugPrint("Klaida apdorojant reitingą: $e");
      }
    }

    // Filtravimas pagal rėžimą (Scope)
    if (_selectedScope == "MANO LYGIS") {
      tempList = tempList.where((e) => e.level == _selectedLevel).toList();
      // Rūšiuojame pagal tikrąjį (Vietinį) RP
      tempList.sort((a, b) => b.rollingRp.compareTo(a.rollingRp));
    } else {
      // GLOBALUS - Rūšiuojame pagal konvertuotą (Svorio) RP
      tempList.sort((a, b) => b.globalRp.compareTo(a.globalRp));
    }

    setState(() {
      _rankedUsers = tempList;
    });
  }

  // --- UI DALIS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: QortColors.surface,
        elevation: 0,
        title: Text(
          "REITINGAI",
          style: GoogleFonts.bebasNeue(
            color: QortColors.textPrimary,
            fontSize: 28,
            letterSpacing: 1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: QortColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 1. REŽIMO PASIRINKIMAS (GLOBALUS vs MANO LYGIS)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: QortColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: QortColors.border),
            ),
            child: Row(
              children: [
                _buildScopeToggle("GLOBALUS"),
                _buildScopeToggle("MANO LYGIS"),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // 2. SPORTO ŠAKOS FILTRAS
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _sportsList.length,
              itemBuilder: (context, index) {
                final sport = _sportsList[index];
                final isSel = _selectedSport == sport;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSport = sport;
                      _processAndSortUsers();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSel
                          ? QortColors.primary
                          : QortColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSel ? QortColors.primary : QortColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SportIcons.icon(
                          sport,
                          size: 14,
                          color: isSel ? Colors.white : QortColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          sport.toUpperCase(),
                          style: TextStyle(
                            color: isSel ? Colors.white : QortColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 15),

          // 3. LYGIO FILTRAS (Rodomas tik jei pasirinkta "MANO LYGIS")
          if (_selectedScope == "MANO LYGIS")
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 15),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: 5, // 5 Lygiai
                itemBuilder: (context, index) {
                  int lvl = index + 1;
                  bool isSel = _selectedLevel == lvl;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedLevel = lvl;
                        _processAndSortUsers();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSel
                            ? const Color(0xFFEAB308)
                            : QortColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? Colors.transparent : QortColors.border,
                        ),
                      ),
                      child: Text(
                        "Lygis $lvl",
                        style: TextStyle(
                          color: isSel ? Colors.black : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // INFO TEKSTAS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Row(
              children: [
                const Icon(LucideIcons.info, color: Colors.grey, size: 14),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _selectedScope == "GLOBALUS"
                        ? "Rodomi konvertuoti taškai lyginant su aukščiausiu PRO lygiu."
                        : "Rodomi jūsų lygio varžovai su tikraisiais RP taškais.",
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: QortColors.border),

          // 4. SĄRAŠAS
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                  )
                : _rankedUsers.isEmpty
                ? const Center(
                    child: Text(
                      "Šioje kategorijoje žaidėjų dar nėra.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    color: const Color(0xFF3B82F6),
                    backgroundColor: QortColors.surface,
                    onRefresh: _fetchLeaderboard,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 10, bottom: 40),
                      itemCount: _rankedUsers.length,
                      itemBuilder: (context, index) {
                        return _buildUserRow(_rankedUsers[index], index + 1);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeToggle(String title) {
    bool isSelected = _selectedScope == title;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedScope = title;
            _processAndSortUsers();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : QortColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserRow(LeaderboardEntry user, int rank) {
    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
    } else if (rank == 2)
      rankColor = const Color(0xFFC0C0C0); // Silver
    else if (rank == 3)
      rankColor = const Color(0xFFCD7F32); // Bronze
    else
      rankColor = Colors.grey.shade700;

    // Pasirenkame, kurį skaičių rodyti
    String displayedScore = _selectedScope == "GLOBALUS"
        ? "~${user.globalRp}"
        : "${user.rollingRp}";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: rank <= 3
            ? rankColor.withOpacity(0.05)
            : QortColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank <= 3 ? rankColor.withOpacity(0.3) : QortColors.border,
        ),
      ),
      child: Row(
        children: [
          // VIETA
          SizedBox(
            width: 30,
            child: Text(
              "#$rank",
              style: GoogleFonts.bebasNeue(
                color: rankColor,
                fontSize: rank <= 3 ? 24 : 18,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),

          // NUOTRAUKA (Saugus Fallback, jei StatusAvatar lūžta)
          CircleAvatar(
            radius: 20,
            backgroundColor: QortColors.background,
            backgroundImage: user.photoUrl.isNotEmpty
                ? NetworkImage(user.photoUrl)
                : null,
            child: user.photoUrl.isEmpty
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : "?",
                    style: const TextStyle(color: QortColors.textPrimary),
                  )
                : null,
          ),
          const SizedBox(width: 15),

          // VARDAS IR LYGIS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    color: QortColors.textPrimary,
                    fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    SportLevels.nameFor(
                      _catalogBySport[_selectedSport],
                      user.level,
                    ),
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // TAŠKAI
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                displayedScore,
                style: GoogleFonts.bebasNeue(
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 1,
                ),
              ),
              Text(
                _selectedScope == "GLOBALUS" ? "Global RP" : "Einamieji RP",
                style: const TextStyle(color: Colors.grey, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
