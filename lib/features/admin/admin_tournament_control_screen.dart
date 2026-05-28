import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/widgets/qort_form_help.dart';
import '../design/design_variants_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/query_limits.dart';
import 'package:intl/intl.dart';
import '../tournament/tournament_detail_screen.dart';
import '../tournament/tournament_engine.dart';

class AdminTournamentControlScreen extends StatefulWidget {
  final Map<String, dynamic> tournament;
  const AdminTournamentControlScreen({super.key, required this.tournament});

  @override
  State<AdminTournamentControlScreen> createState() =>
      _AdminTournamentControlScreenState();
}

class _AdminTournamentControlScreenState
    extends State<AdminTournamentControlScreen> {
  bool _isLoading = false;
  List<dynamic> _participants = [];
  List<dynamic> _existingMatches = [];
  List<dynamic> _disputedMatches = [];
  Map<String, bool> _globalInjuries = {};

  List<Map<String, dynamic>> _stages = [];

  List<String> _tournamentDivisions = [];
  List<String> _tabs = ["BENDRA INFO"];
  String _selectedTab = "BENDRA INFO";

  bool _isParticipantsExpanded = false;

  String _venueType = "Aikštelė";
  List<String> _venueTypes = [];
  final List<String> _defaultVenueTypes = [
    "Aikštelė",
    "Kortas",
    "Stalas",
    "Takelis",
    "Lenta",
    "Trasa",
    "Salė",
    "Sektorius",
    "Kitas (įrašyti savo...)",
  ];
  final TextEditingController _customVenueCtrl = TextEditingController();

  final List<String> _schedulingOptions = [
    "Tik Žaidėjai (Patys tariasi)",
    "Mišrus (Org. nuo Atkrintamųjų)",
    "Organizatorius (Veda viską)",
  ];

  final List<String> _allFormats = [
    "Round Robin (Grupės)",
    "Kvalifikacija (Single Elimination)",
    "Single Elimination (Atkrintamosios)",
    "Double Elimination (Dvigubo minuso)",
    "Swiss System (Šveicariška sistema)",
    "Ladder (Piramidė)",
    "Americano",
    "Mexicano",
    "Paguodos turnyras (Consolation)",
  ];

  final List<String> _placesOptions = [
    "Tik nugalėtoją",
    "Dėl 3 vietos",
    "Visas vietas (5, 7, 9...)",
  ];

  @override
  void initState() {
    super.initState();
    _venueTypes = List.from(_defaultVenueTypes);
    _loadData();
  }

  String _generateUuid() {
    final r = Random();
    String h(int l) =>
        List.generate(l, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${h(8)}-${h(4)}-4${h(3)}-a${h(3)}-${h(12)}';
  }

  Map<String, dynamic> _createDefaultStage(int index, String division) {
    return {
      'id': 'stage_${DateTime.now().millisecondsSinceEpoch}_$index',
      'name': '$index ETAPAS',
      'format': 'Round Robin (Grupės)',
      'division': division,
      'group_count': 2,
      'advancing_players': 2,
      'allow_ties': false,
      'points_for_win': 3,
      'points_for_tie': 1,
      'points_for_loss': 0,
      'scheduling_type': 'Tik Žaidėjai (Patys tariasi)',
      'playoff_places': 'Tik nugalėtoją',
      'start_date': null,
      'end_date': null,
      'advance_to': 'none',
      'drop_to': 'none',
    };
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tId = widget.tournament['id'];
      final client = Supabase.instance.client;

      _tournamentDivisions = [];
      if (widget.tournament['divisions'] != null) {
        for (var div in widget.tournament['divisions']) {
          if (div is Map && div['name'] != null) {
            if (!_tournamentDivisions.contains(div['name'])) {
              _tournamentDivisions.add(div['name']);
            }
          } else if (div is String) {
            if (!_tournamentDivisions.contains(div)) {
              _tournamentDivisions.add(div);
            }
          }
        }
      }

      _tabs = ["BENDRA INFO"];
      if (_tournamentDivisions.isNotEmpty) {
        _tabs.addAll(_tournamentDivisions);
      } else {
        _tabs.add("Visi");
        _tournamentDivisions.add("Visi");
      }
      if (!_tabs.contains(_selectedTab)) _selectedTab = _tabs.first;

      final pData = await client
          .from('tournament_participants')
          .select()
          .eq('tournament_id', tId)
          .limit(QueryLimits.tournamentParticipants);

      Map<String, bool> tempGlobalInjuries = {};
      if (pData.isNotEmpty) {
        List<String> userIds = pData
            .map((p) => p['user_id'].toString())
            .toList();
        try {
          final profData = await client
              .from('profiles')
              .select('id, is_injured')
              .inFilter('id', userIds);
          for (var prof in profData) {
            tempGlobalInjuries[prof['id'].toString()] =
                prof['is_injured'] == true;
          }
        } catch (_) {}
      }

      final mData = await client
          .from('matches')
          .select()
          .eq('tournament_id', tId)
          .limit(QueryLimits.tournamentMatches);
      final dMatches = mData.where((m) => m['status'] == 'disputed').toList();

      try {
        final tData = await client
            .from('tournaments')
            .select('stages_config, venue_type')
            .eq('id', tId)
            .maybeSingle();
        if (tData != null) {
          if (tData['venue_type'] != null &&
              tData['venue_type'].toString().isNotEmpty) {
            String vt = tData['venue_type'];
            if (!_venueTypes.contains(vt)) {
              _venueTypes.insert(_venueTypes.length - 1, vt);
            }
            _venueType = vt;
          }

          if (tData['stages_config'] != null) {
            List<dynamic> loadedStages = tData['stages_config'] is List
                ? List.from(tData['stages_config'])
                : [tData['stages_config']];
            if (loadedStages.isNotEmpty) {
              _stages = loadedStages.asMap().entries.map((e) {
                var stageMap = Map<String, dynamic>.from(e.value);
                if (stageMap['id'] == null) {
                  stageMap['id'] =
                      'stage_${DateTime.now().millisecondsSinceEpoch}_${e.key}';
                }
                if (stageMap['advance_to'] == null) {
                  stageMap['advance_to'] = 'none';
                }
                if (stageMap['drop_to'] == null) stageMap['drop_to'] = 'none';
                if (stageMap['division'] == null) {
                  stageMap['division'] = _tournamentDivisions.first;
                }
                return stageMap;
              }).toList();
            } else {
              _stages = [];
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _participants = pData;
          _globalInjuries = tempGlobalInjuries;
          _existingMatches = mData;
          _disputedMatches = dMatches;
          _isLoading = false;
        });
      }
    } catch (e) {
      _showError("Klaida: $e");
    }
  }

  Future<void> _generateBots() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> bots = [];
      int count = 1;

      for (String div in _tournamentDivisions) {
        for (int i = 0; i < 12; i++) {
          // Sugeneruojame 12 botų rimtam testui
          bots.add({
            'tournament_id': widget.tournament['id'],
            'user_id': _generateUuid(),
            'team_name': 'Test Botas $count ($div)',
            'division': div,
            'status': 'active',
          });
          count++;
        }
      }

      await Supabase.instance.client
          .from('tournament_participants')
          .insert(bots);
      _showSuccess("Sėkmingai sugeneruota ${bots.length} testinių žaidėjų!");
      _loadData();
    } catch (e) {
      _showError("Nepavyko sukurti botų. Klaida: $e");
      setState(() => _isLoading = false);
    }
  }

  void _goToMatches() {
    var updatedTournament = Map<String, dynamic>.from(widget.tournament);
    updatedTournament['stages_config'] = _stages;
    updatedTournament['venue_type'] = _venueType;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TournamentDetailScreen(
          tournament: updatedTournament,
          initialTabIndex: 3,
        ),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      String finalVenueType = _venueType;
      if (_venueType == "Kitas (įrašyti savo...)") {
        finalVenueType = _customVenueCtrl.text.trim();
        if (finalVenueType.isEmpty) finalVenueType = "Aikštelė";
      }

      await Supabase.instance.client
          .from('tournaments')
          .update({'stages_config': _stages, 'venue_type': finalVenueType})
          .eq('id', widget.tournament['id']);

      _showSuccess("Nustatymai sėkmingai išsaugoti!");
      _loadData();
    } catch (e) {
      _showError("Klaida išsaugant nustatymus: $e");
    }
  }

  Future<void> _generateGroups() async {
    setState(() => _isLoading = true);
    try {
      await _saveSettings();
      await TournamentEngine.generateTournamentMatches(
        widget.tournament['id'].toString(),
      );
      await TournamentEngine.processInjuries(
        widget.tournament['id'].toString(),
      );
      _showSuccess("Mačai sugeneruoti sėkmingai!");
      _loadData();
    } catch (e) {
      _showError("Klaida generuojant mačus: $e");
    }
  }

  Future<void> _resetMatches() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('matches')
          .delete()
          .eq('tournament_id', widget.tournament['id']);
      await Supabase.instance.client
          .from('tournament_participants')
          .update({
            'manual_rank': null,
            'is_injured': false,
            'ladder_position': null,
            'is_checked_in': false,
            'payment_status': 'pending',
          })
          .eq('tournament_id', widget.tournament['id']);
      _showSuccess("Turnyras pilnai išvalytas!");
    } catch (e) {
      _showError("Klaida valant turnyrą: $e");
    }
    _loadData();
  }

  // NAUJA FUNKCIJA TAŠKŲ DALINIMUI IR UŽDARYMUI
  Future<void> _closeTournamentAndDistributePoints() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(LucideIcons.award, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text(
              "BAIGTI TURNYRĄ?",
              style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 24),
            ),
          ],
        ),
        content: const Text(
          "Ar tikrai norite baigti šį turnyrą/divizioną ir išdalinti RP/XP taškus dalyviams? Šio veiksmo atšaukti nebus galima, o turnyras bus užrakintas.",
          style: TextStyle(color: QortColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Atšaukti", style: TextStyle(color: QortColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "TAIP, BAIGTI IR IŠDALINTI",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await TournamentEngine.distributePointsAndCloseTournament(
        widget.tournament['id'].toString(),
      );
      _showSuccess(
        "Turnyras sėkmingai baigtas! Taškai ir reitingai išdalinti.",
      );
      setState(() {
        widget.tournament['status'] = 'completed';
      });
      _loadData();
    } catch (e) {
      _showError("Klaida uždarant turnyrą: $e");
    }
  }

  void _openBulkScheduler(
    List<dynamic> divMatches,
    List<dynamic> divParticipants,
    List<dynamic> divStages,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkScheduleScreen(
          matches: divMatches,
          participants: divParticipants,
          stages: divStages,
          venueType: _venueType == "Kitas (įrašyti savo...)"
              ? (_customVenueCtrl.text.isEmpty
                    ? "Aikštelė"
                    : _customVenueCtrl.text)
              : _venueType,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _showBroadcastDialog() {
    TextEditingController msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Siųsti pranešimą visiems",
          style: TextStyle(color: QortColors.textPrimary),
        ),
        content: TextField(
          controller: msgCtrl,
          maxLines: 3,
          style: const TextStyle(color: QortColors.textPrimary),
          decoration: InputDecoration(
            hintText:
                "Pvz.: Turnyras vėluos 30 min. Prašome rinktis prie 1 korto.",
            hintStyle: const TextStyle(color: QortColors.textSecondary),
            filled: true,
            fillColor: QortColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Atšaukti", style: TextStyle(color: QortColors.textSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD946EF),
            ),
            icon: const Icon(LucideIcons.send, color: QortColors.textPrimary, size: 16),
            label: const Text(
              "SIŲSTI",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () async {
              if (msgCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await Supabase.instance.client.from('tournament_chat').insert({
                  'tournament_id': widget.tournament['id'],
                  'user_id': Supabase.instance.client.auth.currentUser!.id,
                  'message': "📢 [ORGANIZATORIUS]: ${msgCtrl.text.trim()}",
                });
                _showSuccess("Pranešimas išsiųstas visiems žaidėjams!");
              } catch (e) {
                _showError("Nepavyko išsiųsti: $e");
              }
              setState(() => _isLoading = false);
            },
          ),
        ],
      ),
    );
  }

  void _handleParticipantAction(String action, dynamic participant) async {
    String pId = participant['id'].toString();
    String uId = participant['user_id'].toString();
    bool isCheckedIn = participant['is_checked_in'] == true;
    bool isPaidCash = participant['payment_status'] == 'paid_cash';

    if (action == 'replace') {
      _showReplacementDialog(pId, uId);
      return;
    }

    if (action == 'delete') {
      if (_existingMatches.isNotEmpty) {
        _showError(
          "Negalima ištrinti dalyvio, nes turnyro mačai jau sugeneruoti. Naudokite žaidėjo keitimą arba suteikite W/O (Traumą).",
        );
        return;
      }
      setState(() => _isLoading = true);
      try {
        await Supabase.instance.client
            .from('tournament_participants')
            .delete()
            .eq('id', pId);
        _showSuccess("Dalyvis sėkmingai pašalintas iš turnyro.");
        _loadData();
      } catch (e) {
        _showError("Klaida ištrinant: $e");
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (action == 'wo') {
        await Supabase.instance.client
            .from('tournament_participants')
            .update({'is_injured': true})
            .eq('id', pId);
        await TournamentEngine.processInjuries(
          widget.tournament['id'].toString(),
        );
        _showSuccess("Mačai anuliuoti (Suteiktas W/O).");
      } else if (action == 'undo_wo') {
        await TournamentEngine.revertLocalInjury(
          widget.tournament['id'].toString(),
          pId,
          uId,
        );
        _showSuccess("Trauma atšaukta, W/O panaikintas.");
      } else if (action == 'toggle_checkin') {
        await Supabase.instance.client
            .from('tournament_participants')
            .update({'is_checked_in': !isCheckedIn})
            .eq('id', pId);
        _showSuccess(
          isCheckedIn
              ? "Žaidėjo atvykimas atšauktas."
              : "Žaidėjas atžymėtas kaip atvykęs!",
        );
      } else if (action == 'toggle_payment') {
        await Supabase.instance.client
            .from('tournament_participants')
            .update({'payment_status': isPaidCash ? 'pending' : 'paid_cash'})
            .eq('id', pId);
        _showSuccess(
          isPaidCash
              ? "Mokėjimas atšauktas."
              : "Pažymėta, kad sumokėjo grynais!",
        );
      }
      _loadData();
    } catch (e) {
      _showError("Klaida: $e");
      setState(() => _isLoading = false);
    }
  }

  void _showReplacementDialog(
    String injuredParticipantId,
    String injuredUserId,
  ) {
    List<dynamic> possibleReplacements = _participants
        .where((p) => p['id'].toString() != injuredParticipantId)
        .toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: QortColors.background,
        title: const Text(
          "Pasirinkite pavaduojantį žaidėją",
          style: TextStyle(color: QortColors.textPrimary, fontSize: 16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: possibleReplacements.length,
            itemBuilder: (context, index) {
              var replacement = possibleReplacements[index];
              return ListTile(
                title: Text(
                  replacement['team_name'] ?? 'Nežinomas',
                  style: const TextStyle(color: QortColors.textPrimary),
                ),
                trailing: const Icon(
                  LucideIcons.arrowRightLeft,
                  color: Colors.blue,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _executePlayerSwap(
                    injuredUserId,
                    replacement['user_id'].toString(),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _executePlayerSwap(String oldUserId, String newUserId) async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final res1 = await client
          .from('matches')
          .update({'player1_id': newUserId})
          .eq('tournament_id', widget.tournament['id'])
          .inFilter('status', ['pending', 'active'])
          .eq('player1_id', oldUserId)
          .select();
      final res2 = await client
          .from('matches')
          .update({'player2_id': newUserId})
          .eq('tournament_id', widget.tournament['id'])
          .inFilter('status', ['pending', 'active'])
          .eq('player2_id', oldUserId)
          .select();

      if (res1.isEmpty && res2.isEmpty) {
        _showError("DĖMESIO: Šis žaidėjas neturi jokių aktyvių mačų!");
      } else {
        _showSuccess(
          "Žaidėjas sėkmingai pakeistas visuose nesužaistuose mačuose!",
        );
      }
      _loadData();
    } catch (e) {
      _showError("Klaida keičiant žaidėją: $e");
    }
  }

  void _resolveDisputeDialog(Map<String, dynamic> match) {
    TextEditingController s1Ctrl = TextEditingController();
    TextEditingController s2Ctrl = TextEditingController();

    String p1Name = "Žaidėjas 1";
    String p2Name = "Žaidėjas 2";
    for (var p in _participants) {
      if (p['user_id'] == match['player1_id']) {
        p1Name = p['team_name'] ?? p1Name;
      }
      if (p['user_id'] == match['player2_id']) {
        p2Name = p['team_name'] ?? p2Name;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(LucideIcons.shieldAlert, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              "SPRĘSTI GINČĄ",
              style: GoogleFonts.bebasNeue(color: Colors.red, fontSize: 24),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Žaidėjai nesutaria dėl rezultato. Įveskite galutinį, teisingą rezultatą. Tai uždarys mačą.",
              style: TextStyle(color: QortColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    p1Name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Text(" VS ", style: TextStyle(color: QortColors.textSecondary)),
                Expanded(
                  child: Text(
                    p2Name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: s1Ctrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: QortColors.textPrimary, fontSize: 20),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black45,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    ":",
                    style: TextStyle(color: QortColors.textSecondary, fontSize: 20),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: s2Ctrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: QortColors.textPrimary, fontSize: 20),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black45,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Atšaukti", style: TextStyle(color: QortColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              int s1 = int.tryParse(s1Ctrl.text) ?? 0;
              int s2 = int.tryParse(s2Ctrl.text) ?? 0;
              String? wId = s1 > s2
                  ? match['player1_id']
                  : (s2 > s1 ? match['player2_id'] : null);

              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await Supabase.instance.client
                    .from('matches')
                    .update({
                      'status': 'completed',
                      'score_p1': s1,
                      'score_p2': s2,
                      'winner_id': wId,
                      'match_details': {
                        'score_str': '$s1:$s2 (Admin išspręsta)',
                      },
                    })
                    .eq('id', match['id']);

                _showSuccess("Ginčas išspręstas!");
                _loadData();
              } catch (e) {
                _showError("Klaida: $e");
                setState(() => _isLoading = false);
              }
            },
            child: const Text(
              "PATVIRTINTI GINČO BAIGTĮ",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayoffPreviewDialog(String stageId, String stageName) async {
    setState(() => _isLoading = true);
    try {
      final result = await TournamentEngine.calculatePlayoffQualifiers(
        widget.tournament['id'].toString(),
        stageId,
      );
      if (!mounted) return;
      List<dynamic> qualified = List.from(result['qualified']);
      List<dynamic> eliminated = List.from(result['eliminated']);
      setState(() => _isLoading = false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "$stageName - REZULTATŲ PERŽIŪRA",
                            style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: QortColors.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        "IŠEINA Į PAGRINDINĮ MEDĮ (KVALIFIKAVOSI)",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: qualified.length,
                        itemBuilder: (context, index) {
                          var q = qualified[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              LucideIcons.checkCircle2,
                              color: Colors.green,
                            ),
                            title: Text(
                              q['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "Grupė ${q['group']} • ${q['points']} tšk.",
                              style: const TextStyle(
                                color: QortColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: () {
                                _showSwapDialog(context, q, eliminated, (
                                  replacement,
                                ) {
                                  setModalState(() {
                                    qualified.remove(q);
                                    eliminated.add(q);
                                    eliminated.remove(replacement);
                                    qualified.add(replacement);
                                  });
                                });
                              },
                              child: const Text(
                                "SUKEISTI",
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD946EF),
                        ),
                        icon: const Icon(
                          LucideIcons.gitCommit,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "TVIRTINTI IR PERDUOTI ŽAIDĖJUS TOLIAU",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _saveSettings();
                          setState(() => _isLoading = true);

                          await TournamentEngine.transitionToPlayoffs(
                            widget.tournament['id'].toString(),
                            stageId,
                            qualified,
                            eliminated,
                          );
                          await TournamentEngine.processInjuries(
                            widget.tournament['id'].toString(),
                          );

                          _showSuccess(
                            "Sekantys etapai sėkmingai sugeneruoti!",
                          );
                          _loadData();
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      _showError("Klaida: $e");
    }
  }

  void _showSwapDialog(
    BuildContext context,
    Map<String, dynamic> playerToReplace,
    List<dynamic> eliminated,
    Function(Map<String, dynamic>) onSwap,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: QortColors.background,
        title: Text(
          "Pakeisti žaidėją: ${playerToReplace['name']}",
          style: const TextStyle(color: QortColors.textPrimary, fontSize: 16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: eliminated.length,
            itemBuilder: (context, index) {
              var e = eliminated[index];
              return ListTile(
                title: Text(
                  e['name'],
                  style: const TextStyle(color: QortColors.textPrimary),
                ),
                subtitle: Text(
                  "Grupė ${e['group']} • ${e['points']} tšk.",
                  style: const TextStyle(color: QortColors.textSecondary, fontSize: 12),
                ),
                trailing: const Icon(
                  LucideIcons.arrowRightLeft,
                  color: Colors.blue,
                ),
                onTap: () {
                  onSwap(e);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  void _showSuccess(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _selectStageDate(int stageIndex, String field) async {
    DateTime? current = _stages[stageIndex][field] != null
        ? DateTime.parse(_stages[stageIndex][field])
        : null;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _stages[stageIndex][field] = picked.toIso8601String();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        title: Text(
          "VALDYMO PULTAS",
          style: GoogleFonts.bebasNeue(
            color: p.textPrimary,
            fontSize: 24,
            letterSpacing: 1,
          ),
        ),
        iconTheme: IconThemeData(color: p.textPrimary),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.palette, color: p.textSecondary),
            tooltip: 'Dizaino variantai',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DesignVariantsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD946EF)),
            )
          : Column(
              children: [
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border(bottom: BorderSide(color: p.border)),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    itemBuilder: (ctx, i) {
                      bool isSel = _selectedTab == _tabs[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(
                            _tabs[i].toUpperCase(),
                            style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : p.chipUnselectedText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: p.chipSelected,
                          backgroundColor: p.chipUnselectedBg,
                          side: BorderSide(
                            color: isSel ? p.chipSelected : p.border,
                          ),
                          showCheckmark: false,
                          onSelected: (v) =>
                              setState(() => _selectedTab = _tabs[i]),
                        ),
                      );
                    },
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      24 + MediaQuery.of(context).padding.bottom + 48,
                    ),
                    child: _selectedTab == "BENDRA INFO"
                        ? _buildBendraInfo()
                        : _buildDivisionView(_selectedTab),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBendraInfo() {
    final p = context.qortPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade800],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.users, color: QortColors.textPrimary, size: 35),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "BENDRAI UŽSIREGISTRAVĘ DALYVIAI",
                      style: GoogleFonts.oswald(
                        color: QortColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      "${_participants.length} ŽAIDĖJAI",
                      style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 28,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        _btn(
          "🤖 GENERUOTI BOTUS TESTAVIMUI",
          LucideIcons.bot,
          Colors.greenAccent,
          _generateBots,
        ),
        const SizedBox(height: 15),
        _btn(
          "📢 MASINIS PRANEŠIMAS VISIEMS",
          LucideIcons.mic,
          Colors.yellow,
          _showBroadcastDialog,
        ),
        const SizedBox(height: 15),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: QortColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: QortColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "ŽAIDIMO ERDVĖ (Globalu)",
                style: TextStyle(
                  color: Colors.purpleAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const QortFieldHelpLabel(
                label: "Kaip vadinsime aikšteles visame turnyre?",
                help: QortFormHelpTexts.adminVenueType,
              ),
              _buildDropdown(
                "Vietos Tipas",
                _venueType,
                _venueTypes,
                (v) => setState(() => _venueType = v!),
              ),
              if (_venueType == "Kitas (įrašyti savo...)") ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _customVenueCtrl,
                  style: const TextStyle(color: QortColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: "Pvz.: Ringas, Baseinas...",
                    filled: true,
                    fillColor: const Color(0xFF202025),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                  onPressed: _saveSettings,
                  child: const Text(
                    "IŠSAUGOTI ERDVĘ",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 50),
        Center(
          child: TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text(
                    "Ištrinti viską?",
                    style: TextStyle(color: QortColors.textPrimary),
                  ),
                  content: const Text(
                    "Tai ištrins visus mačus ir rezultatus visuose divizionuose. Ar tikrai norite tęsti?",
                    style: TextStyle(color: QortColors.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Atšaukti"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetMatches();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        "Taip, Ištrinti",
                        style: TextStyle(color: QortColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(
              LucideIcons.rotateCcw,
              color: Colors.red,
              size: 16,
            ),
            label: const Text(
              "IŠTRINTI VISKĄ IR PERKURTI",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivisionView(String division) {
    final p = context.qortPalette;
    List<dynamic> divParticipants = _participants
        .where((p) => p['division'] == division || p['division'] == null)
        .toList();
    List<dynamic> divStages = _stages
        .where((s) => s['division'] == division)
        .toList();
    List<String> divStageIds = divStages
        .map((s) => s['id'].toString())
        .toList();
    List<dynamic> divMatches = _existingMatches
        .where((m) => divStageIds.contains(m['stage']))
        .toList();

    bool hasMatches = divMatches.isNotEmpty;
    bool isCompleted = widget.tournament['status'] == 'completed';

    List<String> validRoutingIds = ['none'];
    List<DropdownMenuItem<String>> routingOptions = [
      const DropdownMenuItem(
        value: 'none',
        child: Text("Niekur (Pabaiga / Iškrenta)"),
      ),
    ];
    for (var s in _stages) {
      String sId = s['id'].toString();
      validRoutingIds.add(sId);
      routingOptions.add(
        DropdownMenuItem(value: sId, child: Text(s['name'] ?? "Etapas")),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(
                  () => _isParticipantsExpanded = !_isParticipantsExpanded,
                ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DALYVIAI (${divParticipants.length})",
                              style: GoogleFonts.bebasNeue(
                                color: p.success,
                                fontSize: 22,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              "Atvykimas, traumos ir mokėjimai",
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isParticipantsExpanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        color: p.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_isParticipantsExpanded)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 10,
                    bottom: 10,
                  ),
                  child: Column(
                    children: divParticipants.asMap().entries.map((entry) {
                      final participant = entry.value;
                      final rowAlt = entry.key.isOdd;
                      bool isGlobalInjured =
                          _globalInjuries[participant['user_id']] == true;
                      bool isLocalInjured = participant['is_injured'] == true;
                      bool isCheckedIn = participant['is_checked_in'] == true;
                      bool isPaidCash =
                          participant['payment_status'] == 'paid_cash';
                      bool isPaidOnline =
                          participant['payment_status'] == 'paid_online';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: rowAlt ? p.listRowAlt : p.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (isGlobalInjured || isLocalInjured)
                                ? Colors.red.withOpacity(0.5)
                                : p.border,
                          ),
                        ),
                        child: ListTile(
                          title: Row(
                            children: [
                              Text(
                                participant['team_name'] ?? 'Dalyvis',
                                style: TextStyle(
                                  color: p.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isCheckedIn)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(
                                    LucideIcons.mapPin,
                                    color: Colors.green,
                                    size: 14,
                                  ),
                                ),
                              if (isPaidCash || isPaidOnline)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    LucideIcons.euro,
                                    color: isPaidOnline
                                        ? Colors.blue
                                        : Colors.orange,
                                    size: 14,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            (isGlobalInjured || isLocalInjured)
                                ? "Traumuotas (W/O aktyvus)"
                                : "Atvyko: ${isCheckedIn ? 'TAIP' : 'NE'} • Apmokėjimas: ${isPaidOnline ? 'BANKU' : (isPaidCash ? 'GRYNAIS' : 'LAUKIA')}",
                            style: TextStyle(
                              color: (isGlobalInjured || isLocalInjured)
                                  ? Colors.red
                                  : p.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: Icon(
                              LucideIcons.moreVertical,
                              color: p.textSecondary,
                            ),
                            color: p.surface,
                            onSelected: (action) => _handleParticipantAction(
                              action,
                              participant,
                            ),
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'toggle_checkin',
                                    child: Text(
                                      isCheckedIn
                                          ? 'Atšaukti Check-in'
                                          : 'Pažymėti, kad ATVYKO',
                                      style: TextStyle(
                                        color: isCheckedIn
                                            ? Colors.grey
                                            : Colors.greenAccent,
                                      ),
                                    ),
                                  ),
                                  if (!isPaidOnline)
                                    PopupMenuItem<String>(
                                      value: 'toggle_payment',
                                      child: Text(
                                        isPaidCash
                                            ? 'Atšaukti Grynuosius'
                                            : 'Sumokėjo GRYNAIS',
                                        style: TextStyle(
                                          color: isPaidCash
                                              ? Colors.grey
                                              : Colors.orangeAccent,
                                        ),
                                      ),
                                    ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem<String>(
                                    value: 'replace',
                                    child: Text(
                                      'Pakeisti kitu žaidėju',
                                      style: TextStyle(color: QortColors.textPrimary),
                                    ),
                                  ),
                                  if (!hasMatches)
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text(
                                        'Ištrinti dalyvį',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  if (!isLocalInjured)
                                    const PopupMenuItem<String>(
                                      value: 'wo',
                                      child: Text(
                                        'Uždėti Traumą (W/O)',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  if (isLocalInjured)
                                    const PopupMenuItem<String>(
                                      value: 'undo_wo',
                                      child: Text(
                                        'Atšaukti Traumą (Undo W/O)',
                                        style: TextStyle(color: Colors.green),
                                      ),
                                    ),
                                ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "DIVIZIONO ETAPAI",
              style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 22,
                letterSpacing: 1,
              ),
            ),
            Text(
              "${divStages.length} Etapai",
              style: const TextStyle(color: QortColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 15),

        ...divStages.asMap().entries.map((entry) {
          int idx = entry.key;
          Map<String, dynamic> stage = entry.value;
          String format = stage['format'] ?? "Round Robin (Grupės)";
          String stageName = stage['name']?.toString() ?? "${idx + 1} ETAPAS";

          if (!validRoutingIds.contains(stage['advance_to'])) {
            stage['advance_to'] = 'none';
          }
          if (!validRoutingIds.contains(stage['drop_to'])) {
            stage['drop_to'] = 'none';
          }

          int realIdx = _stages.indexOf(stage);

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: p.primary.withOpacity(0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: stageName)
                            ..selection = TextSelection.collapsed(
                              offset: stageName.length,
                            ),
                          onChanged: (val) => _stages[realIdx]['name'] = val,
                          style: const TextStyle(
                            color: QortColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (!isCompleted)
                        IconButton(
                          icon: const Icon(
                            LucideIcons.trash2,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _stages.removeAt(realIdx)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStageField(
                        label: "Etapo Formatas",
                        help: QortFormHelpTexts.stageFormat,
                        child: _buildDropdown(
                          "Formatas",
                          format,
                          _allFormats,
                          (v) => setState(() => _stages[realIdx]['format'] = v!),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStageField(
                        label: "Tvarkaraščio Valdymas šiam etapui",
                        help: QortFormHelpTexts.stageScheduling,
                        child: _buildDropdown(
                          "Valdymas",
                          stage['scheduling_type'] ??
                              "Tik Žaidėjai (Patys tariasi)",
                          _schedulingOptions,
                          (v) => setState(
                            () => _stages[realIdx]['scheduling_type'] = v!,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const QortFieldHelpLabel(
                        label: "Etapo Terminai (Tęstiniams turnyrams)",
                        help:
                            '${QortFormHelpTexts.stageStartDate}\n\n${QortFormHelpTexts.stageEndDate}',
                        labelStyle: TextStyle(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: QortColors.textPrimary,
                                backgroundColor: QortColors.background,
                                side: const BorderSide(color: QortColors.border),
                              ),
                              icon: const Icon(
                                LucideIcons.calendar,
                                size: 14,
                                color: QortColors.primary,
                              ),
                              label: Text(
                                stage['start_date'] != null
                                    ? DateFormat('yyyy-MM-dd').format(
                                        DateTime.parse(stage['start_date']),
                                      )
                                    : "Pradžia",
                                style: const TextStyle(
                                  color: QortColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () =>
                                  _selectStageDate(realIdx, 'start_date'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: QortColors.textPrimary,
                                backgroundColor: QortColors.background,
                                side: const BorderSide(color: QortColors.border),
                              ),
                              icon: const Icon(
                                LucideIcons.calendarX,
                                size: 14,
                                color: QortColors.primary,
                              ),
                              label: Text(
                                stage['end_date'] != null
                                    ? DateFormat('yyyy-MM-dd').format(
                                        DateTime.parse(stage['end_date']),
                                      )
                                    : "Pabaiga",
                                style: const TextStyle(
                                  color: QortColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () =>
                                  _selectStageDate(realIdx, 'end_date'),
                            ),
                          ),
                        ],
                      ),

                      if (format.contains("Grupės") ||
                          format.contains("Swiss")) ...[
                        const SizedBox(height: 20),
                        const Divider(color: QortColors.border),
                        const SizedBox(height: 15),
                        _buildStageField(
                          label: "Į kiek grupių dalinsime?",
                          help: QortFormHelpTexts.stageGroupCount,
                          trailing: Text(
                            "Gausis ~${divParticipants.isNotEmpty ? (divParticipants.length / (stage['group_count'] ?? 2)).toStringAsFixed(1) : 0} žaid./gr.",
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                            ),
                          ),
                          child: _buildDropdown(
                            "Grupių skaičius",
                            (_stages[realIdx]['group_count'] ?? 2).toString(),
                            ["1", "2", "3", "4", "6", "8"],
                            (v) => setState(
                              () => _stages[realIdx]['group_count'] =
                                  int.parse(v!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStageField(
                          label: "Kiek žaidėjų išeina į kitą etapą iš grupės?",
                          help: QortFormHelpTexts.stageAdvancing,
                          child: _buildDropdown(
                            "Išeinančių skaičius",
                            (_stages[realIdx]['advancing_players'] ?? 2)
                                .toString(),
                            ["1", "2", "3", "4", "8"],
                            (v) => setState(
                              () => _stages[realIdx]['advancing_players'] =
                                  int.parse(v!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Taškų sistema",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStageField(
                          label: "Ar galimos lygiosios?",
                          help: QortFormHelpTexts.stageAllowTies,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Switch(
                                value: stage['allow_ties'] ?? false,
                                activeThumbColor: Colors.orange,
                                inactiveThumbColor: QortColors.textSecondary,
                                onChanged: (val) => setState(
                                  () => _stages[realIdx]['allow_ties'] = val,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStageField(
                                label: "Pergalė",
                                help: QortFormHelpTexts.stagePointsWin,
                                child: _buildDropdown(
                                  "Pergalė",
                                  (stage['points_for_win'] ?? 3).toString(),
                                  ["1", "2", "3", "4", "5"],
                                  (v) => setState(
                                    () => _stages[realIdx]['points_for_win'] =
                                        int.parse(v!),
                                  ),
                                ),
                              ),
                            ),
                            if (stage['allow_ties'] == true) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStageField(
                                  label: "Lygiosios",
                                  help: QortFormHelpTexts.stagePointsTie,
                                  child: _buildDropdown(
                                    "Lygiosios",
                                    (stage['points_for_tie'] ?? 1).toString(),
                                    ["0", "1", "2"],
                                    (v) => setState(
                                      () => _stages[realIdx]['points_for_tie'] =
                                          int.parse(v!),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStageField(
                                label: "Pralaimėjimas",
                                help: QortFormHelpTexts.stagePointsLoss,
                                child: _buildDropdown(
                                  "Pralaimėjimas",
                                  (stage['points_for_loss'] ?? 0).toString(),
                                  ["0", "1", "2"],
                                  (v) => setState(
                                    () => _stages[realIdx]['points_for_loss'] =
                                        int.parse(v!),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (format.contains("Elimination") ||
                          format.contains("Atkrintamosios") ||
                          format.contains("Kvalifikacija") ||
                          format.contains("Paguodos")) ...[
                        const SizedBox(height: 20),
                        const Divider(color: QortColors.border),
                        const SizedBox(height: 15),
                        _buildStageField(
                          label: "Kiek vietų išžaisti?",
                          help: QortFormHelpTexts.stagePlayoffPlaces,
                          child: _buildDropdown(
                            "Vietos",
                            stage['playoff_places'] ?? "Tik nugalėtoją",
                            _placesOptions,
                            (v) => setState(
                              () => _stages[realIdx]['playoff_places'] = v!,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      const Divider(color: QortColors.border),
                      const SizedBox(height: 15),
                      const Row(
                        children: [
                          Icon(
                            LucideIcons.gitMerge,
                            color: Colors.green,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "KRYŽKELĖS (Kur keliauja žaidėjai po etapo?)",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      _buildStageField(
                        label: "Kur keliauja laimėtojai / išeinantys iš grupės?",
                        help: QortFormHelpTexts.stageAdvanceTo,
                        child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: QortColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: QortColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: stage['advance_to'],
                            isExpanded: true,
                            dropdownColor: QortColors.surface,
                            style: const TextStyle(
                              color: QortColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            items: routingOptions,
                            onChanged: (v) => setState(
                              () => _stages[realIdx]['advance_to'] = v!,
                            ),
                          ),
                        ),
                      ),
                      ),

                      const SizedBox(height: 12),
                      _buildStageField(
                        label: "Kur keliauja pralaimėtojai / neišeinantys?",
                        help: QortFormHelpTexts.stageDropTo,
                        child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: QortColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: QortColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: stage['drop_to'],
                            isExpanded: true,
                            dropdownColor: QortColors.surface,
                            style: const TextStyle(
                              color: QortColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            items: routingOptions,
                            onChanged: (v) => setState(
                              () => _stages[realIdx]['drop_to'] = v!,
                            ),
                          ),
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        if (!isCompleted)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(LucideIcons.plus, color: Colors.blue),
              label: const Text(
                "PRIDĖTI NAUJĄ ETAPĄ ŠIAM DIVIZIONUI",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                setState(() {
                  _stages.add(
                    _createDefaultStage(_stages.length + 1, division),
                  );
                });
              },
            ),
          ),

        if (!isCompleted)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(LucideIcons.save, color: QortColors.textPrimary),
                label: const Text(
                  "IŠSAUGOTI ETAPUS",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _saveSettings,
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(LucideIcons.info, size: 16, color: QortColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Slinkite žemyn — apačioje taškų sistema, kryžkelės ir veiksmai.',
                  style: TextStyle(
                    color: QortColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "DIVIZIONO VEIKSMAI",
          style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),

        if (!isCompleted)
          _btn(
            "1. GENERUOTI MAČUS (Visam turnyrui)",
            LucideIcons.playCircle,
            const Color(0xFFD946EF),
            _generateGroups,
            on: !hasMatches,
          ),

        if (hasMatches) ...[
          if (!isCompleted) ...[
            const SizedBox(height: 15),
            _btn(
              "TVARKARAŠČIO PLANUOKLIS",
              LucideIcons.calendarClock,
              Colors.blueAccent,
              () => _openBulkScheduler(divMatches, divParticipants, divStages),
            ),
          ],

          const SizedBox(height: 15),

          if (!isCompleted)
            ...divStages.map((stage) {
              bool hasActiveMatches = divMatches.any(
                (m) => m['stage'] == stage['id'],
              );
              bool hasRouting =
                  stage['advance_to'] != 'none' || stage['drop_to'] != 'none';

              if (hasActiveMatches && hasRouting) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: _btn(
                    "BAIGTI: ${stage['name']} -> PERDUOTI TOLIAU",
                    LucideIcons.gitMerge,
                    Colors.orange,
                    () => _showPlayoffPreviewDialog(
                      stage['id'].toString(),
                      stage['name']?.toString() ?? 'Etapas',
                    ),
                    on: true,
                  ),
                );
              }
              return const SizedBox();
            }),

          _btn(
            "PERŽIŪRĖTI REZULTATUS",
            LucideIcons.trophy,
            Colors.green,
            _goToMatches,
          ),

          // --- NAUJAS UŽDARYMO MYGTUKAS ---
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: _btn(
                "🏆 BAIGTI TURNYRĄ IR IŠDALINTI TAŠKUS",
                LucideIcons.award,
                Colors.redAccent,
                _closeTournamentAndDistributePoints,
              ),
            ),

          if (isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    const Icon(
                      LucideIcons.checkCircle,
                      color: Colors.green,
                      size: 30,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "TURNYRAS BAIGTAS IR UŽRAKINTAS",
                      style: GoogleFonts.bebasNeue(
                        color: Colors.green,
                        fontSize: 24,
                        letterSpacing: 1,
                      ),
                    ),
                    const Text(
                      "RP ir XP taškai sėkmingai išdalinti žaidėjams.",
                      style: TextStyle(color: QortColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          // --------------------------------
        ],
      ],
    );
  }

  Widget _buildStageField({
    required String label,
    required String help,
    required Widget child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: QortFieldHelpLabel(
                label: label,
                help: help,
                labelStyle: const TextStyle(
                  color: QortColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        child,
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    if (!items.contains(value)) items.add(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: QortColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: QortColors.background,
          style: const TextStyle(color: QortColors.textPrimary, fontSize: 14),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _btn(String t, IconData i, Color c, VoidCallback f, {bool on = true}) {
    return Opacity(
      opacity: on ? 1 : 0.5,
      child: Material(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: on ? f : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(
                color: on ? c.withOpacity(0.5) : QortColors.border,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(i, color: c),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    t,
                    style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Icon(LucideIcons.chevronRight, color: Colors.white30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BulkScheduleScreen extends StatefulWidget {
  final List<dynamic> matches;
  final List<dynamic> participants;
  final List<dynamic> stages;
  final String venueType;

  const BulkScheduleScreen({
    super.key,
    required this.matches,
    required this.participants,
    required this.stages,
    required this.venueType,
  });

  @override
  State<BulkScheduleScreen> createState() => _BulkScheduleScreenState();
}

class _BulkScheduleScreenState extends State<BulkScheduleScreen> {
  bool _isLoading = false;
  late List<dynamic> _localMatches;

  @override
  void initState() {
    super.initState();
    _localMatches = List.from(widget.matches);
  }

  String _getPlayerName(String? id) {
    if (id == null) return "TBD (Laukiama)";
    for (var p in widget.participants) {
      if (p['user_id'] == id) return p['team_name'] ?? "Žaidėjas";
    }
    return "Nežinomas";
  }

  Future<void> _shiftAllTimes(int minutes) async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      for (int i = 0; i < _localMatches.length; i++) {
        var m = _localMatches[i];
        if (m['scheduled_time'] != null &&
            m['status'] != 'completed' &&
            m['status'] != 'cancelled') {
          DateTime dt = DateTime.parse(
            m['scheduled_time'],
          ).toLocal().add(Duration(minutes: minutes));
          String newIso = dt.toUtc().toIso8601String();
          await client
              .from('matches')
              .update({'scheduled_time': newIso})
              .eq('id', m['id']);
          _localMatches[i]['scheduled_time'] = newIso;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Laikai sėkmingai pastumti!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Klaida: $e"), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  void _showEditDialog(Map<String, dynamic> match, int index) {
    DateTime? selectedDate = match['scheduled_time'] != null
        ? DateTime.parse(match['scheduled_time']).toLocal()
        : null;
    TimeOfDay? selectedTime = selectedDate != null
        ? TimeOfDay.fromDateTime(selectedDate)
        : null;
    TextEditingController locationCtrl = TextEditingController(
      text: match['location_name']?.toString() ?? '',
    );
    TextEditingController venueCtrl = TextEditingController(
      text: match['venue_name']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return QortFormDialog.shell(
            title: Text(
              "Redaguoti Mačą #${match['match_num'] ?? '?'}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const QortHelpBanner(
                    title: 'Tvarkaraščio planavimas',
                    bullets: QortFormHelpTexts.bulkSchedule,
                    accentColor: Colors.blue,
                  ),
                  Text(
                    "${_getPlayerName(match['player1_id'])} VS ${_getPlayerName(match['player2_id'])}",
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Data",
                      style: TextStyle(color: QortColors.textSecondary),
                    ),
                    subtitle: Text(
                      selectedDate != null
                          ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                          : "Nepasirinkta",
                      style: const TextStyle(color: QortColors.textPrimary),
                    ),
                    trailing: const Icon(
                      LucideIcons.calendar,
                      color: Colors.blue,
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setModalState(() => selectedDate = d);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Laikas",
                      style: TextStyle(color: QortColors.textSecondary),
                    ),
                    subtitle: Text(
                      selectedTime != null
                          ? selectedTime!.format(context)
                          : "Nepasirinkta",
                      style: const TextStyle(color: QortColors.textPrimary),
                    ),
                    trailing: const Icon(LucideIcons.clock, color: Colors.blue),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (t != null) setModalState(() => selectedTime = t);
                    },
                  ),
                  TextField(
                    controller: locationCtrl,
                    style: const TextStyle(color: QortColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: "Arena / Aikštynas",
                      labelStyle: TextStyle(color: QortColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: QortColors.border),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.purpleAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: venueCtrl,
                    style: const TextStyle(color: QortColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: widget.venueType,
                      labelStyle: const TextStyle(color: QortColors.textSecondary),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: QortColors.border),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              QortFormDialog.cancelButton(ctx),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text(
                  "IŠSAUGOTI",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  String? isoTime;
                  if (selectedDate != null && selectedTime != null) {
                    isoTime = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    ).toUtc().toIso8601String();
                  }
                  setState(() => _isLoading = true);
                  Navigator.pop(ctx);
                  try {
                    await Supabase.instance.client
                        .from('matches')
                        .update({
                          'scheduled_time': isoTime,
                          'location_name': locationCtrl.text.trim(),
                          'venue_name': venueCtrl.text.trim(),
                        })
                        .eq('id', match['id']);
                    setState(() {
                      _localMatches[index]['scheduled_time'] = isoTime;
                      _localMatches[index]['location_name'] = locationCtrl.text
                          .trim();
                      _localMatches[index]['venue_name'] = venueCtrl.text
                          .trim();
                      _isLoading = false;
                    });
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Klaida: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<dynamic>> grouped = {};
    for (var m in _localMatches) {
      String stageId = m['stage']?.toString() ?? '';
      String stageLabel = "Kiti Mačai";
      var matchingStages = widget.stages
          .where((s) => s['id'] == stageId)
          .toList();
      if (matchingStages.isNotEmpty) {
        stageLabel = (matchingStages.first['name'] ?? "Etapas")
            .toString()
            .toUpperCase();
      }
      grouped.putIfAbsent(stageLabel, () => []).add(m);
    }

    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: QortColors.surface,
        title: Text(
          "TVARKARAŠČIO PLANUOKLIS",
          style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        iconTheme: const IconThemeData(color: QortColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.clock4, color: Colors.orange),
            onPressed: () => _shiftAllTimes(30),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : ListView(
              padding: const EdgeInsets.all(15),
              children: [
                const QortHelpBanner(
                  title: 'Tvarkaraščio planuoklis',
                  bullets: QortFormHelpTexts.bulkSchedule,
                  accentColor: Colors.blue,
                ),
                ...grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 15, bottom: 10),
                      child: Text(
                        entry.key,
                        style: GoogleFonts.bebasNeue(
                          color: Colors.blueAccent,
                          fontSize: 24,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    ...entry.value.map((m) {
                      int idx = _localMatches.indexOf(m);
                      String st = m['scheduled_time'] != null
                          ? DateFormat('MM-dd HH:mm').format(
                              DateTime.parse(m['scheduled_time']).toLocal(),
                            )
                          : "Nepaskirta";
                      return Card(
                        color: QortColors.surface,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            "${_getPlayerName(m['player1_id'])} VS ${_getPlayerName(m['player2_id'])}",
                            style: const TextStyle(
                              color: QortColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            st,
                            style: TextStyle(
                              color: st == "Nepaskirta"
                                  ? QortColors.textSecondary
                                  : Colors.blue,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            LucideIcons.edit,
                            color: QortColors.textSecondary,
                          ),
                          onTap: () => _showEditDialog(m, idx),
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
              ],
            ),
    );
  }
}
