import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_mode_colors.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/widgets/qort_form_help.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'standings_tab.dart';
import 'tournament_bracket_view.dart';
import 'tournament_chat_tab.dart';
import 'schedule_tab.dart';
import 'ladder_tab.dart';
import 'tournament_engine.dart';
import '../../core/services/match_auto_activate_service.dart';
import '../../core/services/match_dispute_service.dart';
import '../../core/widgets/match_dispute_dialog.dart';
import '../../core/constants/query_limits.dart';
import '../../core/constants/match_constants.dart';
import '../../core/models/sport_catalog_entry.dart';
import '../../core/services/tournament_registration_service.dart';
import '../../core/services/sports_catalog_service.dart';
import '../../core/utils/sport_levels.dart';
import '../../core/utils/tournament_format_utils.dart';
import '../teams/create_team_screen.dart';
import '../teams/team_model.dart';
import '../../core/widgets/stock_image_attribution.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TournamentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tournament;
  final int initialTabIndex;
  const TournamentDetailScreen({
    super.key,
    required this.tournament,
    this.initialTabIndex = 0,
  });
  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _participants = [];
  List<dynamic> _matches = [];
  String _matchFormat = "Standard";
  bool _isLoading = true;
  String? _currentUserId;
  bool _isAdmin = false;
  bool _isParticipating = false;
  List<dynamic> _stages = [];

  int _myLevelInThisSport = 1;
  SportCatalogEntry? _sportCatalogEntry;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _currentUserId = user?.id;
    _isAdmin = widget.tournament['owner_id'] == _currentUserId;

    _matchFormat = widget.tournament['match_format'] ?? "Standard";

    if (widget.tournament['stages_config'] != null) {
      _stages = widget.tournament['stages_config'] is List
          ? List.from(widget.tournament['stages_config'])
          : [widget.tournament['stages_config']];
    }

    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final tId = widget.tournament['id'].toString();
      final client = Supabase.instance.client;

      await _checkAutoConfirmations(tId);
      await MatchAutoActivateService.processForTournament(tId);
      await TournamentEngine.reconcileBracketAdvances(tId);

      final results = await Future.wait([
        client
            .from('tournament_participants')
            .select('*')
            .eq('tournament_id', tId)
            .limit(QueryLimits.tournamentParticipants),
        client
            .from('matches')
            .select('*')
            .eq('tournament_id', tId)
            .order('round', ascending: true)
            .order('group_name', ascending: true)
            .order('match_num', ascending: true)
            .limit(QueryLimits.tournamentMatches),
      ]);

      final pData = results[0] as List<dynamic>;
      final mData = results[1] as List<dynamic>;

      bool amIIn = false;
      if (_currentUserId != null) {
        amIIn = pData.any((p) => p['user_id'] == _currentUserId);

        final sportRow = await client
            .from('user_sports')
            .select('level')
            .eq('user_id', _currentUserId!)
            .eq('sport', widget.tournament['sport']?.toString() ?? '')
            .maybeSingle();
        if (sportRow != null) {
          _myLevelInThisSport =
              int.tryParse(sportRow['level']?.toString() ?? '1') ?? 1;
        }
        _sportCatalogEntry = await SportsCatalogService.byName(
          widget.tournament['sport']?.toString() ?? '',
        );
      }

      if (mounted) {
        setState(() {
          _participants = pData;
          _matches = mData;
          _isParticipating = amIIn;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _shareTournament() {
    final t = widget.tournament;
    final startDate = t['start_date'] != null
        ? DateFormat('yyyy-MM-dd').format(DateTime.parse(t['start_date']))
        : "Nenurodyta";

    final text =
        "🔥 Kviečiu dalyvauti turnyre: ${t['name']}!\n"
        "📍 Vieta: ${t['location'] ?? '-'}\n"
        "📅 Data: $startDate\n"
        "💶 Kaina: ${t['entry_fee'] ?? '0'} €\n\n"
        "👉 Parsisiųskite programėlę ir registruokitės!";

    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Kvietimas nukopijuotas! Galite įklijuoti jį į SMS, Messenger ar kitur.",
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  // --- ATNAUJINTA: Išmanus divizionų pasirinkimas su lygio patikrinimu ---
  void _showDivisionSelection() {
    List<Map<String, dynamic>> divisions = [];

    // Saugus duomenų ištraukimas (tvarkome seną ir naują struktūras)
    if (widget.tournament['divisions'] != null) {
      for (var div in widget.tournament['divisions']) {
        if (div is String) {
          // Seni turnyrai, kur divizionas buvo tik tekstas
          divisions.add({'name': div, 'min_level': 1, 'max_level': 5});
        } else if (div is Map) {
          divisions.add(Map<String, dynamic>.from(div));
        }
      }
    }

    if (divisions.isEmpty) {
      _startRegistration(null);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  "PASIRINKITE LYGĮ / KATEGORIJĄ",
                  style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 26,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Tavo lygis profilyje: ${SportLevels.nameFor(_sportCatalogEntry, _myLevelInThisSport)}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: QortModeColors.competition,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 25),
                ...divisions.map((div) {
                  String name = div['name'] ?? "Kategorija";
                  int minLvl = div['min_level'] ?? 1;
                  int maxLvl = div['max_level'] ?? 5;

                  bool isLevelValid =
                      _myLevelInThisSport >= minLvl &&
                      _myLevelInThisSport <= maxLvl;

                  String errorMsg = "";
                  if (_myLevelInThisSport < minLvl) {
                    errorMsg =
                        "Tavo lygis per žemas šiai kategorijai (Min: ${SportLevels.nameFor(_sportCatalogEntry, minLvl)})";
                  }
                  if (_myLevelInThisSport > maxLvl) {
                    errorMsg =
                        "Tavo lygis per aukštas šiai kategorijai (Max: ${SportLevels.nameFor(_sportCatalogEntry, maxLvl)})";
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: QortColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLevelValid
                            ? QortModeColors.competition
                            : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 22,
                              ),
                            ),
                            Text(
                              div['min_level_label'] != null
                                  ? "${div['min_level_label']} – ${div['max_level_label']}"
                                  : SportLevels.rangeLabel(
                                      _sportCatalogEntry,
                                      minLvl,
                                      maxLvl,
                                    ),
                              style: const TextStyle(
                                color: QortColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (!isLevelValid)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.alertCircle,
                                  color: Colors.red,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    errorMsg,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLevelValid
                                  ? QortModeColors.competition
                                  : Colors.grey[800],
                              foregroundColor: isLevelValid
                                  ? Colors.white
                                  : Colors.grey[500],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: isLevelValid
                                ? () {
                                    Navigator.pop(context);
                                    _startRegistration(name);
                                  }
                                : null,
                            child: Text(
                              isLevelValid
                                  ? "PASIRINKTI ŠIĄ KATEGORIJĄ"
                                  : "NEATITINKA LYGIO",
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startRegistration(String? selectedDivision) {
    if (TournamentFormatUtils.requiresTeamRegistration(widget.tournament)) {
      _showTeamRegistrationPicker(selectedDivision);
    } else {
      _joinTournamentIndividual(selectedDivision);
    }
  }

  Future<void> _showTeamRegistrationPicker(String? selectedDivision) async {
    if (_currentUserId == null) return;

    setState(() => _isLoading = true);
    List<Team> teams = [];
    try {
      teams = await TournamentRegistrationService.fetchEligibleTeams(
        userId: _currentUserId!,
        tournament: widget.tournament,
      );
    } catch (e) {
      debugPrint("Klaida kraunant komandas: $e");
    }
    if (!mounted) return;
    setState(() => _isLoading = false);

    final minRoster = TournamentFormatUtils.minRosterSize(widget.tournament);
    final formatLabel = widget.tournament['team_format'] ?? '2v2';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "PASIRINKITE KOMANDĄ / PORĄ",
                  style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 24,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Formatas: $formatLabel • reikia bent $minRoster narių",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: QortColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                if (teams.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: const Text(
                      "Neturite tinkamos komandos šiam turnyrui. "
                      "Sukurkite komandą su tuo pačiu sportu ir formatu (pvz. 2v2), "
                      "pakvieskite partnerį, tada grįžkite registruotis.",
                      style: TextStyle(color: Colors.orange, fontSize: 13, height: 1.4),
                    ),
                  )
                else
                  ...teams.map((team) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        tileColor: QortColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: QortColors.border),
                        ),
                        title: Text(
                          team.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          "${team.memberCount} nariai • ${team.format ?? '-'}",
                          style: const TextStyle(color: QortColors.textSecondary),
                        ),
                        trailing: const Icon(
                          LucideIcons.chevronRight,
                          color: QortModeColors.competition,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _joinTournamentWithTeam(team, selectedDivision);
                        },
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateTeamScreen(),
                      ),
                    );
                    if (created == true && mounted) {
                      _showTeamRegistrationPicker(selectedDivision);
                    }
                  },
                  icon: const Icon(LucideIcons.plus, color: QortColors.textPrimary),
                  label: const Text("SUKURTI NAUJĄ KOMANDĄ"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: QortColors.navInactive),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _joinTournamentWithTeam(
    Team team,
    String? selectedDivision,
  ) async {
    if (_currentUserId == null) return;
    setState(() => _isLoading = true);
    try {
      final err = await TournamentRegistrationService.registerTeam(
        tournamentId: widget.tournament['id'].toString(),
        userId: _currentUserId!,
        team: team,
        currentParticipants: _participants,
        tournament: widget.tournament,
        division: selectedDivision,
      );
      if (!mounted) return;
      if (err != null) {
        _showError(err);
        setState(() => _isLoading = false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Komanda „${team.name}“ užregistruota!"),
          backgroundColor: Colors.green,
        ),
      );
      await _loadAllData();
    } catch (e) {
      _showError("Nepavyko užsiregistruoti: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinTournamentIndividual(String? selectedDivision) async {
    if (_currentUserId == null) return;

    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final profile = await client
          .from('profiles')
          .select('nickname, name, surname, email')
          .eq('id', _currentUserId!)
          .single();
      String displayName = profile['nickname']?.toString().trim() ?? '';
      if (displayName.isEmpty) {
        final full =
            '${profile['name'] ?? ''} ${profile['surname'] ?? ''}'.trim();
        displayName = full.isNotEmpty ? full : profile['email']?.toString() ?? '';
      }
      if (displayName.isEmpty) displayName = "Žaidėjas";

      final err = await TournamentRegistrationService.registerIndividual(
        tournamentId: widget.tournament['id'].toString(),
        userId: _currentUserId!,
        displayName: displayName,
        currentParticipants: _participants,
        tournament: widget.tournament,
        division: selectedDivision,
      );

      if (!mounted) return;
      if (err != null) {
        _showError(err);
        setState(() => _isLoading = false);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sėkmingai užsiregistravote!"),
          backgroundColor: Colors.green,
        ),
      );
      await _loadAllData();
    } catch (e) {
      _showError("Nepavyko užsiregistruoti: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveTournament() async {
    if (_currentUserId == null) return;
    if (_matches.isNotEmpty) {
      _showError("Turnyras jau prasidėjo, pasitraukti negalima.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('tournament_participants')
          .delete()
          .eq('tournament_id', widget.tournament['id'])
          .eq('user_id', _currentUserId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Jūs pasitraukėte iš turnyro."),
            backgroundColor: Colors.orange,
          ),
        );
        _loadAllData();
      }
    } catch (e) {
      _showError("Klaida: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAutoConfirmations(String tId) async {
    try {
      final now = DateTime.now().toUtc();
      final pendingMatches = await Supabase.instance.client
          .from('matches')
          .select()
          .eq('tournament_id', tId)
          .eq('status', 'played_waiting')
          .limit(QueryLimits.autoCompleteMatches);

      for (var m in pendingMatches) {
        final match = Map<String, dynamic>.from(m as Map);
        DateTime? enteredAt;
        if (match['submitted_at'] != null) {
          enteredAt = DateTime.parse(match['submitted_at'].toString()).toUtc();
        } else {
          final details = match['match_details'];
          if (details is Map && details['score_entered_at'] != null) {
            enteredAt =
                DateTime.parse(details['score_entered_at'].toString()).toUtc();
          } else if (match['updated_at'] != null) {
            enteredAt = DateTime.parse(match['updated_at'].toString()).toUtc();
          }
        }
        if (enteredAt == null) continue;

        final diff = now.difference(enteredAt);
        if (diff >= MatchConstants.scoreConfirmationTimeout) {
          await _finalizeMatch(match, MatchConstants.autoConfirmCompletionNote);
        }
      }
    } catch (_) {}
  }

  String _findName(dynamic userId) {
    if (userId == null) return "---";
    final cleanId = userId.toString().trim();
    for (var p in _participants) {
      if (p['user_id'].toString().trim() == cleanId) {
        return p['team_name'] ?? "Be vardo";
      }
    }
    return "Žaidėjas";
  }

  void _showScoreDialog(
    Map<String, dynamic> match, {
    bool isAdminOverride = false,
  }) {
    final p1Name = _findName(match['player1_id']);
    final p2Name = _findName(match['player2_id']);

    List<Map<String, TextEditingController>> sets = [
      {
        'p1': TextEditingController(),
        'p2': TextEditingController(),
        'tb': TextEditingController(),
      },
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return QortFormDialog.shell(
            title: Center(
              child: Text(
                isAdminOverride ? "ADMIN KOREGAVIMAS" : "ĮVESTI REZULTATĄ",
                style: GoogleFonts.bebasNeue(fontSize: 24),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const QortHelpBanner(
                    title: 'Rezultato įvedimas',
                    bullets: QortFormHelpTexts.scoreEntry,
                    accentColor: QortModeColors.competition,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p1Name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Text("VS", style: TextStyle(color: QortColors.textSecondary)),
                      Expanded(
                        child: Text(
                          p2Name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ...List.generate(sets.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            child: Text(
                              "${i + 1}.",
                              style: const TextStyle(
                                color: QortColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _scoreInputBox(sets[i]['p1']!),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              ":",
                              style: TextStyle(color: QortColors.textSecondary),
                            ),
                          ),
                          _scoreInputBox(sets[i]['p2']!),
                          const SizedBox(width: 10),
                          _tbInputBox(sets[i]['tb']!),

                          if (i > 0)
                            IconButton(
                              icon: const Icon(
                                LucideIcons.minusCircle,
                                color: Colors.red,
                                size: 18,
                              ),
                              onPressed: () =>
                                  setStateDialog(() => sets.removeAt(i)),
                            )
                          else
                            const SizedBox(width: 48),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => setStateDialog(() {
                      sets.add({
                        'p1': TextEditingController(),
                        'p2': TextEditingController(),
                        'tb': TextEditingController(),
                      });
                    }),
                    icon: const Icon(
                      LucideIcons.plus,
                      color: Colors.blue,
                      size: 16,
                    ),
                    label: const Text(
                      "Pridėti",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              QortFormDialog.cancelButton(context),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAdminOverride
                      ? Colors.red
                      : QortModeColors.competition,
                ),
                onPressed: () {
                  int p1SetsWon = 0;
                  int p2SetsWon = 0;
                  List<String> formattedSets = [];

                  for (var s in sets) {
                    String v1 = s['p1']!.text.trim();
                    String v2 = s['p2']!.text.trim();
                    String tb = s['tb']!.text.trim();

                    if (v1.isEmpty && v2.isEmpty) continue;

                    int i1 = int.tryParse(v1) ?? 0;
                    int i2 = int.tryParse(v2) ?? 0;

                    if (i1 > i2) {
                      p1SetsWon++;
                    } else if (i2 > i1)
                      p2SetsWon++;

                    String setString = "$v1:$v2";
                    if (tb.isNotEmpty) {
                      setString += " ($tb)";
                    }
                    formattedSets.add(setString);
                  }

                  String finalScoreStr = formattedSets.join(", ");

                  if (isAdminOverride) {
                    _saveScoreAdmin(match, p1SetsWon, p2SetsWon, finalScoreStr);
                  } else {
                    _submitScoreProposal(
                      match,
                      p1SetsWon,
                      p2SetsWon,
                      finalScoreStr,
                    );
                  }
                  Navigator.pop(context);
                },
                child: Text(
                  isAdminOverride ? "PATVIRTINTI (ADMIN)" : "PATEIKTI",
                  style: const TextStyle(color: QortColors.textPrimary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _scoreInputBox(TextEditingController ctrl) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: QortColors.border),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 18),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(bottom: 12),
        ),
      ),
    );
  }

  Widget _tbInputBox(TextEditingController ctrl) {
    return Container(
      width: 60,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.orange, fontSize: 12),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: "Papildoma",
          hintStyle: TextStyle(fontSize: 10, color: QortColors.textSecondary),
          contentPadding: EdgeInsets.only(bottom: 14),
        ),
      ),
    );
  }

  Future<void> _submitScoreProposal(
    Map<String, dynamic> match,
    int s1,
    int s2,
    String details,
  ) async {
    try {
      await Supabase.instance.client
          .from('matches')
          .update({
            'score_p1': s1,
            'score_p2': s2,
            'status': 'played_waiting',
            'match_details': {'score_str': details},
            'submitter_id': _currentUserId,
            'submitted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', match['id']);
      _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Rezultatas pateiktas! Laukite varžovo patvirtinimo.",
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _finalizeMatch(Map<String, dynamic> match, String reason) async {
    try {
      await TournamentEngine.finalizeMatchAndAdvance(
        matchId: match['id'].toString(),
        completionNote: reason,
      );
      _loadAllData();
    } catch (e) {
      debugPrint("Klaida finalizuojant: $e");
    }
  }

  Future<void> _saveScoreAdmin(
    Map<String, dynamic> match,
    int s1,
    int s2,
    String details,
  ) async {
    try {
      await TournamentEngine.finalizeMatchAndAdvance(
        matchId: match['id'].toString(),
        scoreP1: s1,
        scoreP2: s2,
        completionNote: 'Admin override',
        scoreStr: details,
      );
      _loadAllData();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rpValue = widget.tournament['rp_value'] ?? 1000;
    final palette = context.qortPalette;

    bool isLadder = widget.tournament['format'] == "Ladder (Piramidė)";
    String schedulingType = "Tik Žaidėjai (Patys tariasi)";

    if (_stages.isNotEmpty) {
      if (_stages[0]['format'] == "Ladder (Piramidė)") {
        isLadder = true;
      }
      if (_stages[0]['scheduling_type'] != null) {
        schedulingType = _stages[0]['scheduling_type'];
      }
    }

    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.surfaceElevated,
                Color.lerp(
                  palette.surface,
                  QortModeColors.competition,
                  0.1,
                )!,
                palette.background,
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: palette.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          (widget.tournament['name'] ?? "TURNYRAS").toString().toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
            letterSpacing: 0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.share2, color: palette.textPrimary),
            tooltip: "Dalintis",
            onPressed: _shareTournament,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: QortModeColors.competition,
          labelColor: palette.textPrimary,
          unselectedLabelColor: palette.textSecondary,
          isScrollable: true,
          labelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
          tabs: [
            const Tab(text: "INFO"),
            const Tab(text: "LENTELĖ"),
            isLadder ? const Tab(text: "PIRAMIDĖ") : const Tab(text: "MEDIS"),
            const Tab(text: "MAČAI"),
            const Tab(text: "DALYVIAI"),
            const Tab(icon: Icon(LucideIcons.messageCircle, size: 18)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: QortColors.surface,
            border: Border(top: BorderSide(color: QortColors.border)),
          ),
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? const SizedBox(
                  height: 50,
                  child: Center(child: CircularProgressIndicator()),
                )
              : (_isParticipating
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: Colors.red),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _leaveTournament,
                        child: Text(
                          "IŠEITI IŠ TURNYRO",
                          style: GoogleFonts.bebasNeue(
                            fontSize: 22,
                            color: Colors.red,
                            letterSpacing: 1,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QortModeColors.competition,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _showDivisionSelection,
                        child: Text(
                          TournamentFormatUtils.requiresTeamRegistration(
                                widget.tournament,
                              )
                              ? "REGISTRUOTI KOMANDĄ ($rpValue RP)"
                              : "DALYVAUTI (Kovoti dėl $rpValue RP)",
                          style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, letterSpacing: 1,
                          ),
                        ),
                      )),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: QortModeColors.competition),
            )
          : TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _tabController,
              children: [
                _buildInfoTab(),
                StandingsTab(
                  tournamentId: widget.tournament['id'].toString(),
                  stages: _stages,
                ),
                isLadder
                    ? LadderTab(
                        tournamentId: widget.tournament['id'].toString(),
                        currentUserId: _currentUserId,
                      )
                    : TournamentBracketView(
                        matches: _matches,
                        participants: _participants,
                        stages: _stages,
                      ),
                ScheduleTab(
                  matches: _matches,
                  participants: _participants,
                  stages: _stages,
                  currentUserId: _currentUserId,
                  isAdmin: _isAdmin,
                  venueType: widget.tournament['venue_type'] ?? "Aikštelė",
                  schedulingType: schedulingType,
                  onEnterScore: (m) =>
                      _showScoreDialog(m, isAdminOverride: _isAdmin),
                  onConfirmScore: (m) => _finalizeMatch(m, "Confirmed"),
                  onDisputeScore: (m) async {
                    final myId = _currentUserId;
                    if (myId == null) return;

                    final oppId = m['player1_id'] == myId
                        ? m['player2_id']
                        : m['player1_id'];
                    final reason = await showMatchDisputeDialog(
                      context,
                      opponentName: _findName(oppId),
                    );
                    if (reason == null || !mounted) return;

                    try {
                      await MatchDisputeService.submitDispute(
                        matchId: m['id'].toString(),
                        reason: reason,
                        submittedByUserId: myId,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Skundas išsiųstas organizatoriui'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                      _loadAllData();
                    } catch (e) {
                      _showError('Nepavyko pateikti skundo: $e');
                    }
                  },
                  onMatchesActivated: _loadAllData,
                ),
                _buildParticipantsTab(),
                TournamentChatTab(
                  tournamentId: widget.tournament['id'].toString(),
                  isAdmin: _isAdmin,
                ),
              ],
            ),
    );
  }

  Widget _buildInfoTab() {
    final t = widget.tournament;

    String startDate = "Nenurodyta";
    String endDate = "Nenurodyta";
    try {
      if (t['start_date'] != null) {
        startDate = DateFormat(
          'yyyy-MM-dd HH:mm',
        ).format(DateTime.parse(t['start_date']));
      }
      if (t['end_date'] != null) {
        endDate = DateFormat(
          'yyyy-MM-dd HH:mm',
        ).format(DateTime.parse(t['end_date']));
      }
    } catch (_) {}

    final bool hasOrganizerOrSponsor =
        (t['organizer']?.toString().isNotEmpty == true) ||
        (t['sponsor']?.toString().isNotEmpty == true);

    final coverUrl = t['image_url']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coverUrl != null && coverUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            StockImageAttribution(data: t),
            const SizedBox(height: 20),
          ] else if (StockImageAttribution.shouldShow(t)) ...[
            StockImageAttribution(data: t),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: QortColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                top: BorderSide(color: QortColors.border),
                right: BorderSide(color: QortColors.border),
                bottom: BorderSide(color: QortColors.border),
                left: BorderSide(color: QortColors.border),
              ),
            ),
            child: Column(
              children: [
                _infoRow(LucideIcons.calendar, "Pradžia", startDate),
                const Divider(color: QortColors.border, height: 20),
                _infoRow(LucideIcons.flag, "Pabaiga", endDate),
                const Divider(color: QortColors.border, height: 20),
                _infoRow(
                  LucideIcons.mapPin,
                  "Vieta",
                  t['location'] ?? "Nenurodyta",
                ),
                const Divider(color: QortColors.border, height: 20),
                _infoRow(
                  LucideIcons.euro,
                  "Dalyvio mokestis",
                  t['entry_fee'] != null && t['entry_fee'] > 0
                      ? "${t['entry_fee']} €"
                      : "Nemokama",
                ),
                const Divider(color: QortColors.border, height: 20),
                if (t['team_format'] != null)
                  ...[
                    _infoRow(
                      LucideIcons.layoutGrid,
                      "Formatas",
                      t['team_format']?.toString() ?? '1v1',
                    ),
                    const Divider(color: QortColors.border, height: 20),
                  ],
                _infoRow(
                  LucideIcons.users,
                  TournamentFormatUtils.requiresTeamRegistration(t)
                      ? "Komandų / porų"
                      : "Dalyvių skaičius",
                  "${TournamentRegistrationService.countOccupiedSlots(_participants, t)} / ${t['max_participants'] ?? '-'}",
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          if (hasOrganizerOrSponsor) ...[
            Text(
              "ORGANIZATORIUS IR RĖMĖJAI",
              style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 22,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: QortColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: QortColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (t['organizer']?.toString().isNotEmpty == true)
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.building,
                          color: QortColors.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Organizuoja: ",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "${t['organizer']}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                  if (t['organizer']?.toString().isNotEmpty == true &&
                      t['sponsor']?.toString().isNotEmpty == true)
                    const SizedBox(height: 10),

                  if (t['sponsor']?.toString().isNotEmpty == true)
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.briefcase,
                          color: QortColors.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Pagrindinis Rėmėjas: ",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "${t['sponsor']}",
                          style: const TextStyle(
                            color: QortModeColors.competition,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                  if (t['sponsor_image_url']?.toString().isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 15),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        t['sponsor_image_url'],
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],

          if (_stages.isNotEmpty) ...[
            Text(
              "TURNYRO ETAPAI",
              style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 22,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            ..._stages.asMap().entries.map((entry) {
              int idx = entry.key;
              Map<String, dynamic> stage = entry.value;

              Color accentColor = QortModeColors.competition;
              if (stage['format'].toString().contains('Atkrintamosios') ||
                  stage['format'].toString().contains('Elimination')) {
                accentColor = Colors.orangeAccent;
              }

              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: QortColors.surface,
                    border: Border.all(color: QortColors.border),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 4, color: accentColor),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          "${idx + 1}",
                          style: GoogleFonts.bebasNeue(
                            color: accentColor,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (stage['name'] ?? 'Etapas')
                                .toString()
                                .toUpperCase(),
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${stage['format']}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
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
            }),
            const SizedBox(height: 30),
          ],

          if (t['prize_pool']?.toString().isNotEmpty == true ||
              t['prizes_info']?.toString().isNotEmpty == true) ...[
            Text(
              "PRIZINIS FONDAS IR DOVANOS",
              style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 22,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: QortColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: QortColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (t['prize_pool']?.toString().isNotEmpty == true) ...[
                    Text(
                      "Prizinis fondas:",
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    Text(
                      "${t['prize_pool']}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (t['prizes_info']?.toString().isNotEmpty == true) ...[
                    Text(
                      "Papildoma informacija:",
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${t['prizes_info']}",
                      style: const TextStyle(
                        color: QortColors.textSecondary,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],

          Text(
            "APRAŠYMAS",
            style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 22,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t['description']?.toString().isNotEmpty == true
                ? t['description']
                : "Organizatorius nepateikė aprašymo.",
            style: const TextStyle(color: QortColors.textSecondary, height: 1.5),
          ),

          const SizedBox(height: 30),

          Text(
            "TAISYKLĖS IR SĄLYGOS",
            style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 22,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t['rules']?.toString().isNotEmpty == true
                ? t['rules']
                : "Nėra specialių taisyklių.",
            style: const TextStyle(color: QortColors.textSecondary, height: 1.5),
          ),

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: QortModeColors.competition, size: 20),
        const SizedBox(width: 15),
        Text(label, style: const TextStyle(color: QortColors.textSecondary, fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _participants.length,
      separatorBuilder: (_, __) => const Divider(color: QortColors.border),
      itemBuilder: (context, index) {
        final p = _participants[index];
        final division = p['division'];

        return ListTile(
          leading: Text(
            "#${index + 1}",
            style: const TextStyle(color: QortColors.textSecondary),
          ),
          title: Text(
            p['team_name'] ?? "-",
            style: const TextStyle(color: QortColors.textPrimary),
          ),
          trailing: division != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: QortModeColors.competition.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: QortModeColors.competition),
                  ),
                  child: Text(
                    division,
                    style: const TextStyle(
                      color: QortModeColors.competition,
                      fontSize: 12,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
