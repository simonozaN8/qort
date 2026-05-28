import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/query_limits.dart';
import '../../core/theme/qort_colors.dart';
import 'add_external_record_screen.dart';

class MyRecordsScreen extends StatefulWidget {
  const MyRecordsScreen({super.key});

  @override
  State<MyRecordsScreen> createState() => _MyRecordsScreenState();
}

class _MyRecordsScreenState extends State<MyRecordsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _records = [];
  String _filter = "all"; // all | qort | external_tournament | friendly
  String? _selectedSport; // null = visi sportai
  List<String> _userSports = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    // Užkrauname vartotojo sportus (tik pirmą kartą)
    if (_userSports.isEmpty) {
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          final sportsResp = await Supabase.instance.client
              .from('user_sports')
              .select('sport')
              .eq('user_id', session.user.id);
          _userSports = (sportsResp as List)
              .map((s) => s['sport'] as String)
              .toList();
        }
      } catch (e) {
        debugPrint("Klaida kraunant sportus: $e");
      }
    }
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final myId = session.user.id;
      final supabase = Supabase.instance.client;

      // 1. Užkrauname VISUS duomenis paraleliai (greičiau)
      final results = await Future.wait([
        // Išoriniai įrašai
        supabase
            .from('external_records')
            .select()
            .eq('user_id', myId)
            .order('date_played', ascending: false)
            .limit(QueryLimits.myRecords),
        supabase
            .from('matches')
            .select('*, tournaments(name, sport)')
            .or('player1_id.eq.$myId,player2_id.eq.$myId')
            .eq('status', 'completed')
            .order('match_date', ascending: false)
            .limit(QueryLimits.myRecords),
      ]);

      // 2. Išoriniai įrašai
      final externalRecords = List<Map<String, dynamic>>.from(
        results[0] as List,
      );

      // 3. Užkrauname setus tik išoriniams įrašams
      if (externalRecords.isNotEmpty) {
        final recordIds = externalRecords
            .map((r) => r['id'] as String)
            .toList();
        final setsResponse = await supabase
            .from('match_sets')
            .select()
            .inFilter('record_id', recordIds)
            .order('set_number');

        final allSets = List<Map<String, dynamic>>.from(setsResponse);

        for (var record in externalRecords) {
          record['sets'] = allSets
              .where((s) => s['record_id'] == record['id'])
              .toList();
          record['_source'] = 'external';
        }
      }

      // 4. QORT matčai
      final qortMatches = List<Map<String, dynamic>>.from(results[1] as List);

      // Užkrauname varžovų vardus
      final opponentIds = <String>{};
      for (var m in qortMatches) {
        if (m['player1_id'] != myId && m['player1_id'] != null) {
          opponentIds.add(m['player1_id']);
        }
        if (m['player2_id'] != myId && m['player2_id'] != null) {
          opponentIds.add(m['player2_id']);
        }
      }

      Map<String, String> opponentNames = {};
      if (opponentIds.isNotEmpty) {
        final profilesResponse = await supabase
            .from('profiles')
            .select('id, nickname, name')
            .inFilter('id', opponentIds.toList());

        for (var p in (profilesResponse as List)) {
          final name = (p['nickname'] as String?)?.isNotEmpty == true
              ? p['nickname']
              : p['name'] ?? '?';
          opponentNames[p['id']] = name;
        }
      }

      // Pažymime QORT matčus
      for (var m in qortMatches) {
        m['_source'] = 'qort';
        // Nustatome, ar aš laimėjau
        m['_i_won'] = m['winner_id'] == myId;
        // Varžovo vardas
        final oppId = m['player1_id'] == myId
            ? m['player2_id']
            : m['player1_id'];
        m['_opponent_name'] = opponentNames[oppId] ?? '?';
        // Tikras rezultatas yra match_details.score_str (pvz. "6:3 2:6 3:6")
        final matchDetails = m['match_details'] as Map<String, dynamic>?;
        final scoreStr = matchDetails?['score_str'] as String? ?? '';
        m['_score_str'] = scoreStr;

        // Žaidėjo perspektyva: ar jis player1, ar player2
        m['_am_i_player1'] = m['player1_id'] == myId;
        // Turnyro pavadinimas
        m['_tournament_name'] =
            (m['tournaments'] as Map?)?['name'] ?? 'QORT turnyras';
        m['_sport'] = (m['tournaments'] as Map?)?['sport'] ?? '';
        // Data
        m['_date'] = m['match_date'] ?? m['created_at'];
      }

      // 5. Sujungiame visus įrašus į vieną sąrašą
      final allRecords = <Map<String, dynamic>>[];
      allRecords.addAll(externalRecords);
      allRecords.addAll(qortMatches);

      // 6. Rūšiuojame pagal datą (naujausi viršuje)
      allRecords.sort((a, b) {
        final dateA = a['_source'] == 'qort' ? a['_date'] : a['date_played'];
        final dateB = b['_source'] == 'qort' ? b['_date'] : b['date_played'];
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.toString().compareTo(dateA.toString());
      });

      if (mounted) {
        setState(() {
          _records = allRecords;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant rezultatus: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openAddScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddExternalRecordScreen()),
    );

    // Jei buvo išsaugotas naujas įrašas - perkrauname sąrašą
    if (result == true) {
      _loadRecords();
    }
  }

  Future<void> _deleteRecord(String recordId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: QortColors.surface,
        title: const Text(
          "Ištrinti įrašą?",
          style: TextStyle(color: QortColors.textPrimary),
        ),
        content: const Text(
          "Šis veiksmas yra negrįžtamas.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Atšaukti"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ištrinti", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('external_records')
          .delete()
          .eq('id', recordId);

      _loadRecords();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Įrašas ištrintas"),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Nepavyko ištrinti: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredRecords {
    // Pirma filtruojame pagal tipą
    List<Map<String, dynamic>> result;

    if (_filter == "all") {
      result = List.from(_records);
    } else if (_filter == "qort") {
      result = _records.where((r) => r['_source'] == 'qort').toList();
    } else if (_filter == "external_tournament") {
      result = _records
          .where(
            (r) =>
                r['_source'] == 'external' && r['record_type'] == 'tournament',
          )
          .toList();
    } else if (_filter == "friendly") {
      result = _records
          .where(
            (r) => r['_source'] == 'external' && r['record_type'] == 'friendly',
          )
          .toList();
    } else {
      result = List.from(_records);
    }

    // Tada filtruojame pagal sporto šaką (jei pasirinkta)
    if (_selectedSport != null) {
      result = result.where((r) {
        final sport = r['_source'] == 'qort' ? r['_sport'] : r['sport'];
        return sport == _selectedSport;
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = QortColors.primary;

    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: QortColors.surface,
        elevation: 0,
        title: Text(
          "MANO REZULTATAI",
          style: GoogleFonts.bebasNeue(
            color: QortColors.textPrimary,
            letterSpacing: 2,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: QortColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _openAddScreen,
              icon: const Icon(
                LucideIcons.plus,
                color: Color(0xFF3B82F6),
                size: 18,
              ),
              label: Text(
                "IŠORINIS",
                style: GoogleFonts.bebasNeue(
                  color: const Color(0xFF3B82F6),
                  letterSpacing: 1.5,
                  fontSize: 14,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6).withOpacity(0.15),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // SPORTŲ FILTRAS
          if (_userSports.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _sportChip("Visi sportai", null, accentColor),
                    const SizedBox(width: 8),
                    ..._userSports.map(
                      (sport) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _sportChip(sport, sport, accentColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // TIPO FILTRAS
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip("Visi", "all", accentColor),
                  const SizedBox(width: 8),
                  _filterChip("QORT turnyrai", "qort", accentColor),
                  const SizedBox(width: 8),
                  _filterChip(
                    "Išorės turnyrai",
                    "external_tournament",
                    accentColor,
                  ),
                  const SizedBox(width: 8),
                  _filterChip("Draugiški", "friendly", accentColor),
                ],
              ),
            ),
          ),
          // SĄRAŠAS
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: accentColor),
                  )
                : _filteredRecords.isEmpty
                ? _buildEmpty(accentColor)
                : RefreshIndicator(
                    onRefresh: _loadRecords,
                    color: accentColor,
                    backgroundColor: QortColors.surface,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredRecords.length,
                      itemBuilder: (context, index) {
                        return _buildRecordCard(
                          _filteredRecords[index],
                          accentColor,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sportChip(String label, String? value, Color accentColor) {
    final isSelected = _selectedSport == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedSport = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.withOpacity(0.2) : QortColors.border,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.orange : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, Color accentColor) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : QortColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? accentColor : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: QortColors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(Color accentColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.fileQuestion, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              "Dar nėra rezultatų",
              style: GoogleFonts.bebasNeue(
                fontSize: 24,
                color: QortColors.textPrimary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Pridėk savo turnyrų ir matčų istoriją,\nkad sektum savo progresą.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openAddScreen,
              icon: const Icon(LucideIcons.plus),
              label: const Text("PRIDĖTI IŠORINĮ"),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record, Color accentColor) {
    // QORT matčai — atskira kortelė
    if (record['_source'] == 'qort') {
      return _buildQortMatchCard(record, accentColor);
    }

    final isTournament = record['record_type'] == 'tournament';
    final status = record['status'] ?? 'completed';
    final iWon = record['i_won'] as bool?;
    final isTeam = record['is_team_match'] == true;

    // Spalva pagal rezultatą
    Color borderColor = Colors.white12;
    if (!isTournament && iWon != null) {
      borderColor = iWon ? Colors.green : Colors.red;
    }
    if (isTournament && status == 'in_progress') {
      borderColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ANTRAŠTĖ
          Row(
            children: [
              Icon(
                isTournament ? LucideIcons.trophy : LucideIcons.users,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                isTournament ? "TURNYRAS" : "DRAUGIŠKAS",
                style: GoogleFonts.bebasNeue(
                  color: accentColor,
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(record['date_played']),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteRecord(record['id']),
                child: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: Colors.white30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // TURINYS PAGAL TIPĄ
          if (isTournament)
            _buildTournamentContent(record, status)
          else
            _buildFriendlyContent(record, isTeam, iWon),

          // SPORTAS
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: QortColors.border,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              record['sport'] ?? '',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // PASTABOS
          if (record['notes'] != null &&
              (record['notes'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              record['notes'],
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // === QORT MATČO KORTELĖ ===
  Widget _buildQortMatchCard(Map<String, dynamic> record, Color accentColor) {
    final iWon = record['_i_won'] as bool;
    final opponentName = record['_opponent_name'] as String;
    final tournamentName = record['_tournament_name'] as String;
    final sport = record['_sport'] as String;
    final scoreStr = record['_score_str'] as String;
    final amIPlayer1 = record['_am_i_player1'] as bool;
    final stage = record['stage'] as String? ?? '';
    final groupName = record['group_name'] as String? ?? '';

    // Paskaidome rezultatą į setus pagal tarpus
    // Pvz: "6:3 2:6 3:6" -> [{my: "6", opp: "3"}, {my: "2", opp: "6"}, {my: "3", opp: "6"}]
    final List<Map<String, String>> setsList = [];
    String? specialNote; // Pvz "W/O (Trauma)"

    if (scoreStr.isNotEmpty) {
      // Palaikome abu formatus:
      //   Naujas: "6:4 3:6 7:5" (tarpai tarp setų, dvitaškis viduje)
      //   Senas:  "6-4, 6-2" (kableliai, brūkšniai vietoj dvitaškio)

      // Pirma normalizuojam: kableliai ir brūkšniai - į standartinį formatą
      final normalized = scoreStr
          .trim()
          .replaceAll(',', ' ') // kableliai į tarpus
          .replaceAll('-', ':') // brūkšniai į dvitaškius
          .replaceAll(RegExp(r'\s+'), ' '); // dvigubi tarpai į vieną

      // Tikriname, ar yra speciali žinutė be skaičių (pvz "W/O (Trauma)")
      if (!normalized.contains(':')) {
        specialNote = scoreStr; // Originalus tekstas
      } else {
        // Skaidome į setus
        final parts = normalized.split(' ');
        for (var part in parts) {
          part = part.trim();
          if (part.isEmpty) continue;

          if (part.contains(':')) {
            final scores = part.split(':');
            if (scores.length == 2 &&
                scores[0].trim().isNotEmpty &&
                scores[1].trim().isNotEmpty) {
              setsList.add({
                'my': amIPlayer1 ? scores[0].trim() : scores[1].trim(),
                'opp': amIPlayer1 ? scores[1].trim() : scores[0].trim(),
              });
            }
          }
        }

        // Jei nieko nepavyko paskaidyti - paliekam kaip specialią žinutę
        if (setsList.isEmpty) {
          specialNote = scoreStr;
        }
      }
    }

    final borderColor = iWon ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ANTRAŠTĖ
          Row(
            children: [
              const Icon(
                LucideIcons.trophy,
                size: 18,
                color: Color(0xFFEAB308), // Aukso spalva QORT
              ),
              const SizedBox(width: 8),
              Text(
                "QORT TURNYRAS",
                style: GoogleFonts.bebasNeue(
                  color: const Color(0xFFEAB308),
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(record['_date']),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // TURNYRO PAVADINIMAS
          Text(
            tournamentName,
            style: const TextStyle(
              color: QortColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          // ETAPAS / GRUPĖ
          if (stage.isNotEmpty || groupName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (stage.isNotEmpty) _formatStage(stage),
                if (groupName.isNotEmpty) groupName,
              ].join(" • "),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],

          const SizedBox(height: 10),

          // VARŽOVAS
          Text(
            "vs $opponentName",
            style: const TextStyle(
              color: QortColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),

          // SETAI
          // SETAI
          if (setsList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ...setsList.map((set) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: QortColors.border,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      "${set['my']}:${set['opp']}",
                      style: const TextStyle(
                        color: QortColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: iWon
                        ? Colors.green.withOpacity(0.25)
                        : Colors.red.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    iWon ? "W" : "L",
                    style: TextStyle(
                      color: iWon ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (specialNote != null) ...[
            // Specialus atvejis - pvz "W/O (Trauma)"
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    specialNote,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: iWon
                        ? Colors.green.withOpacity(0.25)
                        : Colors.red.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    iWon ? "W" : "L",
                    style: TextStyle(
                      color: iWon ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // SPORTAS
          if (sport.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: QortColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sport,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatStage(String stage) {
    if (stage == 'group') return 'Grupė';
    if (stage == 'playoffs') return 'Pliai-of';
    if (stage == 'ladder') return 'Laiptai';
    return stage;
  }

  Widget _buildTournamentContent(Map<String, dynamic> record, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          record['tournament_name'] ?? '',
          style: const TextStyle(
            color: QortColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (record['organizer'] != null) ...[
          const SizedBox(height: 4),
          Text(
            record['organizer'],
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
        const SizedBox(height: 8),
        if (status == 'in_progress')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Text(
              "VYKSTA",
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          )
        else if (record['place_taken'] != null)
          Row(
            children: [
              Icon(
                LucideIcons.medal,
                size: 16,
                color: _placeColor(record['place_taken']),
              ),
              const SizedBox(width: 6),
              Text(
                "${record['place_taken']} vieta",
                style: TextStyle(
                  color: _placeColor(record['place_taken']),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (record['total_participants'] != null) ...[
                const SizedBox(width: 4),
                Text(
                  "iš ${record['total_participants']}",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildFriendlyContent(
    Map<String, dynamic> record,
    bool isTeam,
    bool? iWon,
  ) {
    final sets = (record['sets'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Varžovai
        if (isTeam) ...[
          Text(
            "Su: ${record['partner_name'] ?? '?'}",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            "Prieš: ${record['opponent_name'] ?? '?'} ir ${record['opponent2_name'] ?? '?'}",
            style: const TextStyle(
              color: QortColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ] else
          Text(
            "vs ${record['opponent_name'] ?? '?'}",
            style: const TextStyle(
              color: QortColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

        // Setai
        if (sets.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Kiekvienas setas - atskira "pilulė"
              ...sets.map((set) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: QortColors.border,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    "${set['my_score']}:${set['opponent_score']}",
                    style: const TextStyle(
                      color: QortColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }),
              // W / L ženkliukas
              if (iWon != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: iWon
                        ? Colors.green.withOpacity(0.25)
                        : Colors.red.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    iWon ? "W" : "L",
                    style: TextStyle(
                      color: iWon ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ] else if (iWon != null) ...[
          // Jei setų nėra, bet yra W/L
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: iWon
                  ? Colors.green.withOpacity(0.25)
                  : Colors.red.withOpacity(0.25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              iWon ? "Laimėjau" : "Pralaimėjau",
              style: TextStyle(
                color: iWon ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _placeColor(int place) {
    if (place == 1) return const Color(0xFFFFD700); // Auksas
    if (place == 2) return const Color(0xFFC0C0C0); // Sidabras
    if (place == 3) return const Color(0xFFCD7F32); // Bronza
    return Colors.white;
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (e) {
      return date.toString();
    }
  }
}
