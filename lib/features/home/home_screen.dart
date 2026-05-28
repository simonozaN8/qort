import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/query_limits.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_palette.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/services/home_dashboard_service.dart';
import '../../core/services/open_events_service.dart';
import 'home_discover_section.dart';
import 'home_live_widgets.dart';
import 'home_proposal_dialog.dart';
import '../profile/user_model.dart';
import '../tournament/tournament_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppMode currentMode;
  final String userName;
  final ValueChanged<AppMode>? onModeSelected;
  final VoidCallback? onOpenPlayTab;
  final VoidCallback? onOpenQuickActions;

  const HomeScreen({
    super.key,
    required this.currentMode,
    this.userName = 'Žaidėjas',
    this.onModeSelected,
    this.onOpenPlayTab,
    this.onOpenQuickActions,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _currentUserId;

  List<dynamic> _confirmedMatches = [];
  List<dynamic> _incomingProposals = [];
  List<dynamic> _unscheduledMatches = [];
  List<dynamic> _myTournaments = [];
  List<dynamic> _discoverEvents = [];
  int _blitzPoints = 0;
  int _userXp = 0;

  bool get _isPersonalDashboardEmpty =>
      !_isLoading &&
      _confirmedMatches.isEmpty &&
      _incomingProposals.isEmpty &&
      _unscheduledMatches.isEmpty &&
      _myTournaments.isEmpty;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (widget.currentMode == AppMode.competition ||
        widget.currentMode == AppMode.training ||
        widget.currentMode == AppMode.blitz) {
      _loadDashboardData();
    } else {
      _isLoading = false;
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMode != widget.currentMode) {
      if (widget.currentMode == AppMode.competition ||
          widget.currentMode == AppMode.training ||
          widget.currentMode == AppMode.blitz) {
        _loadDashboardData();
      }
    }
  }

  Future<void> _loadDashboardData() async {
    if (_currentUserId == null) return;
    setState(() => _isLoading = true);

    try {
      final dashboardFuture = HomeDashboardService.load(_currentUserId!);
      final discoverFuture = widget.currentMode == AppMode.competition
          ? OpenEventsService.loadOpenEvents(
              limit: QueryLimits.homeDiscoverPreview,
            )
          : Future<List<dynamic>>.value(const []);

      final blitzFuture = widget.currentMode == AppMode.blitz
          ? Supabase.instance.client
              .from('profiles')
              .select('blitz_points, xp')
              .eq('id', _currentUserId!)
              .maybeSingle()
          : Future<Map<String, dynamic>?>.value(null);

      final results = await Future.wait([
        dashboardFuture,
        discoverFuture,
        blitzFuture,
      ]);
      final data = results[0] as HomeDashboardData;
      final discover = results[1] as List<dynamic>;
      final blitzProf = results[2] as Map<String, dynamic>?;

      HomeDashboardData.enrichTournamentProgress(
        myTournaments: data.myTournaments,
        allMatches: data.allMatches,
      );

      if (mounted) {
        setState(() {
          _myTournaments = data.myTournaments;
          _confirmedMatches = data.confirmedMatches;
          _incomingProposals = data.incomingProposals;
          _unscheduledMatches = data.unscheduledMatches;
          _discoverEvents = discover;
          _blitzPoints = (blitzProf?['blitz_points'] as num?)?.toInt() ?? 0;
          _userXp = (blitzProf?['xp'] as num?)?.toInt() ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant Dashboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitScore(
    Map<String, dynamic> match,
    int totalS1,
    int totalS2,
    String scoreString, {
    bool isNoScore = false,
  }) async {
    setState(() => _isLoading = true);
    try {
      String? wId = isNoScore
          ? null
          : ((totalS1 > totalS2) ? match['player1_id'] : match['player2_id']);

      await Supabase.instance.client
          .from('matches')
          .update({
            'status': 'played_waiting',
            'score_p1': totalS1,
            'score_p2': totalS2,
            'winner_id': wId,
            'match_details': {
              'entered_by': _currentUserId,
              'score_str': scoreString,
              'is_no_score': isNoScore,
              'score_entered_at': DateTime.now()
                  .toUtc()
                  .toIso8601String(), // SAUGOJAM TIKSLŲ LAIKĄ
            },
          })
          .eq('id', match['id']);

      _showSuccess(
        "Rezultatas pateiktas! Varžovas turi 1 valandą jį patvirtinti.",
      );
      _loadDashboardData();
    } catch (e) {
      _showError("Nepavyko išsaugoti: $e");
    }
  }

  Future<void> _confirmScore(Map<String, dynamic> match) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('matches')
          .update({'status': 'completed'})
          .eq('id', match['id']);

      _showSuccess("Mačas baigtas ir patvirtintas!");
      _loadDashboardData();
    } catch (e) {
      _showError("Klaida: $e");
    }
  }

  Future<void> _disputeScore(Map<String, dynamic> match) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('matches')
          .update({'status': 'disputed'})
          .eq('id', match['id']);
      _showError(
        "Mačas pažymėtas kaip ginčijamas. Administratorius jį išspręs.",
      );
      _loadDashboardData();
    } catch (e) {
      _showError("Klaida: $e");
    }
  }

  Future<void> _extendMatch(Map<String, dynamic> match) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('matches')
          .update({
            'scheduled_time': null,
            'match_date': null,
            'status': 'pending',
          })
          .eq('id', match['id']);

      await Supabase.instance.client.from('match_chat').insert({
        'match_id': match['id'],
        'user_id': _currentUserId,
        'content':
            "⚠️ Nespėjome sužaisti. Reikia derinti naują laiką pratęsimui.",
      });

      _showSuccess("Mačo laikas anuliuotas pratęsimui.");
      _loadDashboardData();
    } catch (e) {
      _showError("Klaida: $e");
    }
  }

  void _showDynamicScoreDialog(Map<String, dynamic> match) {
    List<TextEditingController> p1Ctrls = [TextEditingController()];
    List<TextEditingController> p2Ctrls = [TextEditingController()];
    List<TextEditingController> tbCtrls = [TextEditingController()];

    bool iAmP1 = match['player1_id'] == _currentUserId;
    String myName = "AŠ";
    String oppName = match['opponent_name'].toString().split(" ").first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: QortColors.surface,
            title: Text(
              "ĮVESTI REZULTATĄ",
              style: GoogleFonts.bebasNeue(
                color: QortColors.textPrimary,
                fontSize: 24,
                letterSpacing: 1,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 25),
                      Expanded(
                        flex: 2,
                        child: Text(
                          myName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: Text(
                          oppName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(flex: 2, child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(p1Ctrls.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Text(
                            "${index + 1}.",
                            style: const TextStyle(
                              color: QortColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: p1Ctrls[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: QortColors.textPrimary,
                                fontSize: 20,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: QortColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              ":",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: p2Ctrls[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: QortColors.textPrimary,
                                fontSize: 20,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: QortColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: tbCtrls[index],
                              keyboardType: TextInputType.text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: "Papildoma",
                                hintStyle: const TextStyle(
                                  color: Colors.white30,
                                  fontSize: 10,
                                ),
                                filled: true,
                                fillColor: QortColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                              ),
                            ),
                          ),
                          if (p1Ctrls.length > 1)
                            IconButton(
                              icon: const Icon(
                                LucideIcons.xCircle,
                                color: Colors.red,
                                size: 16,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  p1Ctrls.removeAt(index);
                                  p2Ctrls.removeAt(index);
                                  tbCtrls.removeAt(index);
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      setModalState(() {
                        p1Ctrls.add(TextEditingController());
                        p2Ctrls.add(TextEditingController());
                        tbCtrls.add(TextEditingController());
                      });
                    },
                    icon: const Icon(
                      LucideIcons.plus,
                      size: 14,
                      color: Colors.blue,
                    ),
                    label: const Text(
                      "PRIDĖTI SETĄ/KĖLINĮ",
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                    ),
                  ),

                  // --- NAUJAS MYGTUKAS: ŽAIDIMAS BE REZULTATO ---
                  const SizedBox(height: 20),
                  const Divider(color: QortColors.border),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _submitScore(
                          match,
                          0,
                          0,
                          "Draugiškas (Be rezultato)",
                          isNoScore: true,
                        );
                      },
                      icon: const Icon(LucideIcons.users, size: 16),
                      label: const Text(
                        "ŽAIDĖME BE REZULTATO",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),
                  const Text(
                    "Pateikus, varžovas turės patvirtinti rezultatą.",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Atšaukti",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  List<String> setScores = [];
                  List<String> dbSetScores = [];
                  int totalP1Win = 0;
                  int totalP2Win = 0;

                  for (int i = 0; i < p1Ctrls.length; i++) {
                    int s1 = int.tryParse(p1Ctrls[i].text) ?? 0;
                    int s2 = int.tryParse(p2Ctrls[i].text) ?? 0;
                    String tb = tbCtrls[i].text.trim();
                    String tbStr = tb.isNotEmpty ? "($tb)" : "";

                    if (p1Ctrls[i].text.isNotEmpty ||
                        p2Ctrls[i].text.isNotEmpty) {
                      if (iAmP1) {
                        setScores.add("$s1:$s2$tbStr");
                        dbSetScores.add("$s1:$s2$tbStr");
                        if (s1 > s2) {
                          totalP1Win++;
                        } else if (s2 > s1)
                          totalP2Win++;
                      } else {
                        setScores.add("$s2:$s1$tbStr");
                        dbSetScores.add("$s2:$s1$tbStr");
                        if (s2 > s1) {
                          totalP1Win++;
                        } else if (s1 > s2)
                          totalP2Win++;
                      }
                    }
                  }

                  if (dbSetScores.isEmpty) return;

                  Navigator.pop(ctx);
                  _submitScore(
                    match,
                    totalP1Win,
                    totalP2Win,
                    dbSetScores.join(", "),
                  );
                },
                child: const Text(
                  "PATEIKTI",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
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

  Future<void> _acceptLadderChallenge(String matchId) async {
    try {
      await Supabase.instance.client
          .from('matches')
          .update({'status': 'active'})
          .eq('id', matchId);
      _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Iššūkis priimtas!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _rejectLadderChallenge(String matchId) async {
    try {
      await Supabase.instance.client
          .from('matches')
          .update({'status': 'cancelled'})
          .eq('id', matchId);
      _loadDashboardData();
    } catch (_) {}
  }

  Future<void> _acceptTimeProposal(Map<String, dynamic> m) async {
    try {
      await Supabase.instance.client
          .from('matches')
          .update({
            'match_date': m['proposed_date'],
            'location': m['proposed_location'],
            'is_proposal_active': false,
            'proposed_date': null,
            'status': 'active',
          })
          .eq('id', m['id']);
      await Supabase.instance.client.from('match_chat').insert({
        'match_id': m['id'],
        'user_id': _currentUserId,
        'content': "✅ Sutiko su pasiūlytu laiku! Iki pasimatymo korte.",
      });
      _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Laikas patvirtintas!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _rejectTimeProposal(Map<String, dynamic> m) async {
    try {
      await Supabase.instance.client
          .from('matches')
          .update({'is_proposal_active': false, 'proposed_date': null})
          .eq('id', m['id']);
      await Supabase.instance.client.from('match_chat').insert({
        'match_id': m['id'],
        'user_id': _currentUserId,
        'content': "❌ Netinka pasiūlytas laikas. Derinkime kitą.",
      });
      _loadDashboardData();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.currentMode) {
      case AppMode.training:
        return _buildTrainingHome(context);
      case AppMode.blitz:
        return _buildBlitzHome(context);
      case AppMode.competition:
      default:
        return _buildCompetitionHome(context);
    }
  }

  Widget _buildCompetitionHome(BuildContext context) {
    return _baseHomeStructure(
      context: context,
      accentColor: const Color(0xFF3B82F6),
      children: _isLoading
          ? [
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
              ),
            ]
          : [
              _homeSummaryStrip(context),
              const SizedBox(height: 20),
              if (_incomingProposals.isNotEmpty ||
                  _unscheduledMatches.isNotEmpty) ...[
                _sectionHeader(
                  'Reikia dėmesio',
                  count: _incomingProposals.length +
                      (_unscheduledMatches.isNotEmpty ? 1 : 0),
                  accent: Colors.orange,
                ),
                const SizedBox(height: 8),
                ..._incomingProposals.map((m) {
                  if (m['card_type'] == 'time_proposal') {
                    String pDate = DateFormat(
                      'MM-dd HH:mm',
                    ).format(DateTime.parse(m['proposed_date']).toLocal());
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _incomingActionCard(
                        context: context,
                        from: m['opponent_name'],
                        details:
                            "Siūlo laiką: $pDate @ ${m['proposed_location'] ?? 'Nenurodyta'} (${m['tournament_name']})",
                        onAccept: () => _acceptTimeProposal(m),
                        onReject: () => _rejectTimeProposal(m),
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _incomingActionCard(
                        context: context,
                        from: m['opponent_name'],
                        details:
                            "Kviečia į dvikovą piramidėje! (${m['tournament_name']})",
                        onAccept: () =>
                            _acceptLadderChallenge(m['id'].toString()),
                        onReject: () =>
                            _rejectLadderChallenge(m['id'].toString()),
                      ),
                    );
                  }
                }),
                if (_unscheduledMatches.isNotEmpty)
                  _multiInviteCard(context, _unscheduledMatches),
                const SizedBox(height: 24),
              ],

              if (_confirmedMatches.isNotEmpty) ...[
                _sectionHeader(
                  'Artimiausi mačai',
                  count: _confirmedMatches.length,
                ),
                const SizedBox(height: 8),
                ..._confirmedMatches.map((m) {
                  String timeStr = "Laukia laiko";
                  DateTime? actualDate;
                  String? rawTime = m['scheduled_time'] ?? m['match_date'];
                  if (rawTime != null) {
                    actualDate = DateTime.parse(rawTime).toLocal();
                    timeStr = DateFormat('MM-dd HH:mm').format(actualDate);
                  }

                  List<String> locParts = [];
                  if (m['location_name'] != null &&
                      m['location_name'].toString().isNotEmpty) {
                    locParts.add(m['location_name']);
                  }
                  if (m['location'] != null &&
                      m['location'].toString().isNotEmpty) {
                    locParts.add(m['location']);
                  }
                  if (m['venue_name'] != null &&
                      m['venue_name'].toString().isNotEmpty) {
                    locParts.add(m['venue_name']);
                  }
                  String locStr = locParts.isNotEmpty
                      ? locParts.join(" - ")
                      : m['tournament_name'];

                  return _matchRow(context, m, timeStr, actualDate, locStr);
                }),
                const SizedBox(height: 24),
              ],

              if (_isPersonalDashboardEmpty) ...[
                HomeStartHereCard(
                  mode: AppMode.competition,
                  onOpenPlayTab: widget.onOpenPlayTab,
                  onOpenQuickActions: widget.onOpenQuickActions,
                ),
                HomeDiscoverSection(
                  events: _discoverEvents,
                  isLoading: false,
                  onSeeAll: widget.onOpenPlayTab,
                ),
                const SizedBox(height: 8),
              ],

              if (_myTournaments.isNotEmpty) ...[
                _sectionHeader(
                  'Mano turnyrai',
                  count: _myTournaments.length,
                ),
                const SizedBox(height: 8),
                ..._myTournaments.map((t) {
                  final tournamentData = t['tournaments'];
                  final name = tournamentData is Map
                      ? (tournamentData['name']?.toString() ?? 'Turnyras')
                      : 'Turnyras';
                  return GestureDetector(
                    onTap: tournamentData is Map
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TournamentDetailScreen(
                                  tournament: Map<String, dynamic>.from(
                                    tournamentData,
                                  ),
                                ),
                              ),
                            ).then((_) => _loadDashboardData());
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _tournamentProgressRow(
                        name,
                        t['status_text'] ?? "Aktyvus",
                        (t['calculated_progress'] as num?)?.toDouble() ?? 0.0,
                        const Color(0xFF3B82F6),
                      ),
                    ),
                  );
                }),
              ] else if (_confirmedMatches.isNotEmpty ||
                  _incomingProposals.isNotEmpty ||
                  _unscheduledMatches.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Turnyrų dar nėra — atidarykite kalendorių (pirmas tab apačioje).',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ],
            ],
    );
  }

  Widget _matchRow(
    BuildContext context,
    Map<String, dynamic> match,
    String timeStr,
    DateTime? matchDate,
    String locStr,
  ) {
    final p = context.qortPalette;
    final accent = widget.currentMode == AppMode.training
        ? const Color(0xFF16C56E)
        : const Color(0xFF3B82F6);

    bool isPlayedWaiting = match['status'] == 'played_waiting';
    bool iEnteredScore =
        match['match_details'] != null &&
        match['match_details']['entered_by'] == _currentUserId;

    bool canEnterScore = false;
    if (matchDate != null && match['status'] != 'played_waiting') {
      if (DateTime.now().isAfter(matchDate.add(const Duration(minutes: 15)))) {
        canEnterScore = true;
      }
    }

    return GestureDetector(
      onTap: () =>
          showPlayerStatsModal(context, match['opponent_name'], 1250, 45000),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _accentSurfaceCard(
            palette: p,
            accent: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                      Row(
                        children: [
                          Icon(LucideIcons.calendar, color: accent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  match['opponent_name']?.toString() ?? 'Varžovas',
                                  style: TextStyle(
                                    color: p.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "$timeStr · $locStr",
                                  style: TextStyle(
                                    color: p.textSecondary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronRight,
                            color: p.textSecondary.withValues(alpha: 0.6),
                            size: 18,
                          ),
                        ],
                      ),

                      if (canEnterScore || isPlayedWaiting) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(color: p.border, height: 1),
                        ),

                        if (canEnterScore)
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _showDynamicScoreDialog(match),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF22C55E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Įvesti rezultatą',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _extendMatch(match),
                                child: Text(
                                  'Pratęsti',
                                  style: TextStyle(
                                    color: Colors.orange.shade300,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                        if (isPlayedWaiting)
                          iEnteredScore
                              ? Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.hourglass,
                                      color: Colors.orange,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Laukiama varžovo patvirtinimo. Jei nepatvirtins per 1 valandą – užsiskaitys automatiškai.",
                                        style: TextStyle(
                                          color: Colors.orange.shade300,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Varžovas įvedė rezultatą: ${match['match_details']?['score_str']}",
                                      style: TextStyle(
                                        color: p.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _confirmScore(match),
                                            icon: const Icon(LucideIcons.check, size: 16),
                                            label: const Text("PATVIRTINTI"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _disputeScore(match),
                                            icon: const Icon(
                                              LucideIcons.shieldAlert,
                                              size: 16,
                                            ),
                                            label: const Text("GINČYTI"),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(color: Colors.red),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                      ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Kairysis akcentas be [IntrinsicHeight] — saugu slenkamame sąraše.
  Widget _accentSurfaceCard({
    required QortPalette palette,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      color: palette.surface,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: accent),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _incomingActionCard({
    required BuildContext context,
    required String from,
    required String details,
    required VoidCallback onAccept,
    required VoidCallback onReject,
  }) {
    return GestureDetector(
      onTap: () => showPlayerStatsModal(context, from, 1320, 12000),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: QortColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: QortColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.bellRing, color: Colors.green, size: 14),
                const SizedBox(width: 6),
                const Text(
                  'Pasiūlymas',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '+20 XP',
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: QortColors.textPrimary),
                children: [
                  TextSpan(
                    text: "$from ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: details,
                    style: const TextStyle(color: QortColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Priimti', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: QortColors.textSecondary,
                      side: const BorderSide(color: QortColors.navInactive),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Atmesti', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMultiInviteDialog(BuildContext context, List<dynamic> matches) {
    HomeProposalDialog.show(
      context: context,
      matches: matches,
      currentUserId: _currentUserId!,
      onSubmitted: () {
        if (mounted) {
          setState(() => _isLoading = true);
          _loadDashboardData();
        }
      },
    );
  }

  Widget _multiInviteCard(
    BuildContext context,
    List<dynamic> unscheduledMatches,
  ) {
    int waitingForOthers = 0;
    int actionNeeded = 0;
    List<dynamic> actionableMatches = [];

    for (var m in unscheduledMatches) {
      if (m['is_proposal_active'] == true &&
          m['proposer_id'] == _currentUserId) {
        waitingForOthers++;
      } else {
        actionNeeded++;
        actionableMatches.add(m);
      }
    }

    if (actionNeeded == 0 && waitingForOthers == 0) return const SizedBox();

    final p = context.qortPalette;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _accentSurfaceCard(
          palette: p,
          accent: Colors.orange,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.clock,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nesuderinti mačai · ${unscheduledMatches.length}',
                      style: TextStyle(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '+10 XP',
                    style: TextStyle(
                      color: Colors.orange.shade300,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                actionNeeded > 0
                    ? 'Pasirinkite varžovus ir siūlykite laiką.'
                    : 'Laukiama atsakymo iš $waitingForOthers varžovų.',
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (actionNeeded > 0) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showMultiInviteDialog(
                      context,
                      actionableMatches,
                    ),
                    icon: const Icon(LucideIcons.send, size: 14),
                    label: const Text('Siūlyti laiką'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tournamentProgressRow(
    String name,
    String status,
    double progress,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QortColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: QortColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: Colors.grey,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                status,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${(progress * 100).toInt()}%",
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: QortColors.border,
            color: color,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingHome(BuildContext context) {
    final sparringMatches = _confirmedMatches
        .where((m) => m['tournament_id'] == null)
        .toList();
    final pendingSparring = _incomingProposals
        .where((m) => m['tournament_id'] == null)
        .toList();

    int totalSparrings = sparringMatches.length + 12; // +12 simuliacijai
    int sparringWins = 8; // Simuliacija

    return _baseHomeStructure(
      context: context,
      accentColor: const Color(0xFF16C56E),
      children: [
        _sectionTitle("TAVO SPARINGŲ STATISTIKA"),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: QortColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      "$totalSparrings",
                      style: GoogleFonts.bebasNeue(
                        fontSize: 36,
                        color: Colors.orange,
                      ),
                    ),
                    const Text(
                      "SUŽAISTA MAČŲ",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: QortColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: QortColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      "$sparringWins",
                      style: GoogleFonts.bebasNeue(
                        fontSize: 36,
                        color: QortColors.textPrimary,
                      ),
                    ),
                    const Text(
                      "PERGALĖS",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),

        if (pendingSparring.isNotEmpty) ...[
          _sectionTitle("GAUTI KVIETIMAI"),
          const SizedBox(height: 10),
          ...pendingSparring.map((m) {
            String pDate = m['proposed_date'] != null
                ? DateFormat(
                    'MM-dd HH:mm',
                  ).format(DateTime.parse(m['proposed_date']).toLocal())
                : "Nenurodyta";
            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: _incomingActionCard(
                context: context,
                from: m['opponent_name'],
                details:
                    "Kviečia į draugišką mačą!\nLaikas: $pDate\nVieta: ${m['proposed_location'] ?? 'Nenurodyta'}",
                onAccept: () => _acceptTimeProposal(m),
                onReject: () => _rejectTimeProposal(m),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],

        _sectionTitle("SUDERINTI DRAUGIŠKI MAČAI"),
        const SizedBox(height: 10),
        if (sparringMatches.isEmpty)
          HomeStartHereCard(
            mode: AppMode.training,
            onOpenPlayTab: widget.onOpenPlayTab,
          )
        else
          ...sparringMatches.map((m) {
            String timeStr = "Laukia laiko";
            DateTime? actualDate;
            String? rawTime = m['scheduled_time'] ?? m['match_date'];
            if (rawTime != null) {
              actualDate = DateTime.parse(rawTime).toLocal();
              timeStr = DateFormat('MM-dd HH:mm').format(actualDate);
            }
            String locStr =
                m['location'] ?? (m['location_name'] ?? "Draugiškas mačas");
            return _matchRow(context, m, timeStr, actualDate, locStr);
          }),
      ],
    );
  }

  Widget _buildBlitzHome(BuildContext context) {
    const accent = Color(0xFF7C3AED);
    final p = context.qortPalette;

    return _baseHomeStructure(
      context: context,
      accentColor: accent,
      children: _isLoading
          ? [
              Center(child: CircularProgressIndicator(color: accent)),
            ]
          : [
              _sectionHeader('Apžvalga', accent: accent),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _blitzStatCard(
                      p,
                      label: 'Blitz taškai',
                      value: '$_blitzPoints',
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _blitzStatCard(
                      p,
                      label: 'XP',
                      value: '$_userXp',
                      color: p.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionHeader('Veiksmai', accent: accent),
              const SizedBox(height: 10),
              _accentSurfaceCard(
                palette: p,
                accent: accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atidaryti Blitz',
                      style: TextStyle(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sukurkite lobby arba prisijunkite prie aktyvaus mačo.',
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: widget.onOpenPlayTab,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Eiti į Blitz'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
    );
  }

  Widget _blitzStatCard(
    QortPalette p, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _baseHomeStructure({
    required BuildContext context,
    required Color accentColor,
    required List<Widget> children,
  }) {
    final actionCount = _incomingProposals.length +
        (_unscheduledMatches.isNotEmpty ? 1 : 0);

    return HomeLiveScaffold(
      mode: widget.currentMode,
      userName: widget.userName,
      upcomingMatches: _confirmedMatches.length,
      actionItems: actionCount,
      isNewUser: _isPersonalDashboardEmpty,
      refreshAccent: accentColor,
      onRefresh: _loadDashboardData,
      onModeSelected: widget.onModeSelected,
      children: children,
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.oswald(
        color: QortColors.textSecondary,
        fontSize: 14,
        letterSpacing: 1,
      ),
    );
  }

  Widget _sectionHeader(String title, {int? count, Color? accent}) {
    final badgeColor = accent ?? const Color(0xFF3B82F6);
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.oswald(
            color: QortColors.textSecondary,
            fontSize: 12,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (count != null && count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Greita santrauka — matoma ir PC (platus ekranas), ne tik „pakeistos spalvos“.
  Widget _homeSummaryStrip(BuildContext context) {
    final actionCount = _incomingProposals.length +
        (_unscheduledMatches.isNotEmpty ? 1 : 0);
    final matchCount = _confirmedMatches.length;
    final tourneyCount = _myTournaments.length;

    return Row(
      children: [
        Expanded(
          child: _summaryChip(
            context: context,
            label: 'Veiksmai',
            value: actionCount,
            color: Colors.orange,
            highlight: actionCount > 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryChip(
            context: context,
            label: 'Mačai',
            value: matchCount,
            color: const Color(0xFF3B82F6),
            highlight: matchCount > 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryChip(
            context: context,
            label: 'Turnyrai',
            value: tourneyCount,
            color: const Color(0xFF22C55E),
            highlight: tourneyCount > 0,
          ),
        ),
      ],
    );
  }

  Widget _summaryChip({
    required BuildContext context,
    required String label,
    required int value,
    required Color color,
    required bool highlight,
  }) {
    final p = context.qortPalette;
    final bgAlpha = highlight ? 0.18 : 0.08;
    final borderAlpha = highlight ? 0.5 : 0.28;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: bgAlpha),
          p.surface,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: borderAlpha)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: highlight ? color : p.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String val, Color c) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(val, style: GoogleFonts.bebasNeue(fontSize: 28, color: c)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}

void showPlayerStatsModal(
  BuildContext context,
  String opponentName,
  int opponentRP,
  int opponentXP,
) {
  const int myRP = 1250;
  double rpDiffFactor = (myRP - opponentRP) / 1000;
  double winProb = 0.5 + rpDiffFactor;
  winProb += 0.05;
  winProb = winProb.clamp(0.15, 0.85);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: QortColors.border)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: QortColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "MAČO APŽVALGA",
                  style: GoogleFonts.bebasNeue(
                    color: QortColors.textPrimary,
                    fontSize: 24,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, color: QortColors.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _playerAvatar("AŠ", myRP, 50000, true),
                      Text(
                        "VS",
                        style: GoogleFonts.bebasNeue(
                          fontSize: 40,
                          color: QortColors.border,
                        ),
                      ),
                      _playerAvatar(
                        opponentName,
                        opponentRP,
                        opponentXP,
                        false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "PROGNOZĖ (PERGALĖS TIKIMYBĖ)",
                      style: GoogleFonts.oswald(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Stack(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: winProb,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${(winProb * 100).toInt()}%",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${((1 - winProb) * 100).toInt()}%",
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  _statRow("REITINGAS (RP/ELO)", "$myRP", "$opponentRP"),
                  _statRow("LAIMĖJIMO %", "75%", "62%"),
                  _statRow("SERIJA (STREAK)", "3W", "1L"),
                  _statRow(
                    "AKTYVUMAS (XP)",
                    "Lvl 50",
                    "Lvl ${(opponentXP / 1000).floor()}",
                  ),
                  const SizedBox(height: 30),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "TARPUSAVIO ISTORIJA",
                      style: GoogleFonts.oswald(
                        color: QortColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _h2hItem("2025-10-12", "Vilnius Open", "Laimėta", "6-4, 7-5"),
                  _h2hItem(
                    "2025-08-01",
                    "Draugiškas",
                    "Pralaimėta",
                    "2-6, 4-6",
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "UŽDARYTI",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _playerAvatar(String name, int rp, int xp, bool isMe) {
  int level = (xp / 1000).floor();
  return Column(
    children: [
      Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: isMe
                ? Colors.blue.withOpacity(0.2)
                : Colors.red.withOpacity(0.2),
            child: Text(
              name[0],
              style: TextStyle(
                fontSize: 24,
                color: isMe ? Colors.blue : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Text(
              "$level",
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        name,
        style: const TextStyle(
          color: QortColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        "$rp RP",
        style: const TextStyle(color: QortColors.textSecondary, fontSize: 12),
      ),
    ],
  );
}

Widget _statRow(String label, String val1, String val2) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            val1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: QortColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: QortColors.textSecondary, fontSize: 12),
        ),
        SizedBox(
          width: 60,
          child: Text(
            val2,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _h2hItem(String date, String event, String result, String score) {
  bool won = result == "Laimėta";
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: QortColors.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: QortColors.border),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event,
              style: const TextStyle(
                color: QortColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              date,
              style: const TextStyle(
                color: QortColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              result,
              style: TextStyle(
                color: won ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              score,
              style: const TextStyle(
                color: QortColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
