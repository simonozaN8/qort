import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/utils/tournament_bracket_utils.dart';
import '../../core/widgets/tournament_group_matrix.dart';

class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class TournamentBracketView extends StatefulWidget {
  final List<dynamic> matches;
  final List<dynamic> participants;
  final List<dynamic> stages;

  const TournamentBracketView({
    super.key,
    required this.matches,
    required this.participants,
    required this.stages,
  });

  @override
  State<TournamentBracketView> createState() => _TournamentBracketViewState();
}

class _TournamentBracketViewState extends State<TournamentBracketView> {
  String? _currentUserId;
  String _selectedStageId = '';
  List<Map<String, dynamic>> _availableStages = [];

  bool _showPodium = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _setupStages();
  }

  void _setupStages() {
    _availableStages = widget.stages
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    _selectedStageId = TournamentBracketUtils.selectDefaultStageId(
      stages: widget.stages,
      matches: widget.matches,
    );
  }

  String _getName(dynamic id) {
    if (id == null) return "---";
    final cleanId = id.toString().trim();
    for (var p in widget.participants) {
      if (p['user_id'].toString() == cleanId) {
        return p['team_name'] ?? "Žaidėjas";
      }
    }
    return "Žaidėjas";
  }

  // Paimame taškus tiesiai iš dalyvių sąrašo, kurį variklis ką tik atnaujino
  int _getEarnedRp(dynamic id) {
    if (id == null) return 0;
    final cleanId = id.toString().trim();
    for (var p in widget.participants) {
      if (p['user_id'].toString() == cleanId) return p['earned_rp'] ?? 0;
    }
    return 0;
  }

  int _getEarnedXp(dynamic id) {
    if (id == null) return 0;
    final cleanId = id.toString().trim();
    for (var p in widget.participants) {
      if (p['user_id'].toString() == cleanId) return p['earned_xp'] ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.matches.isEmpty) {
      return const Center(
        child: Text(
          "Burtai dar negeneruoti",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    List<Map<String, dynamic>> currentStageMatches =
        TournamentBracketUtils.filterMatchesByStage(
          widget.matches,
          _selectedStageId,
        );

    var currentStageData = _availableStages.firstWhere(
      (s) =>
          TournamentBracketUtils.stageKey(s['id']) ==
          TournamentBracketUtils.stageKey(_selectedStageId),
      orElse: () => {'format': 'Round Robin'},
    );
    bool isKnockout =
        currentStageData['format'].toString().contains('Atkrintamosios') ||
        currentStageData['format'].toString().contains('Elimination') ||
        currentStageData['format'].toString().contains('Kvalifikacija') ||
        currentStageData['format'].toString().contains('Paguodos');

    bool isStageCompleted = false;
    Map<String, dynamic>? finalMatch;

    if (isKnockout && currentStageMatches.isNotEmpty) {
      var knockoutMatches = currentStageMatches
          .where((m) => (int.tryParse(m['round'].toString()) ?? 1) < 50)
          .toList();
      if (knockoutMatches.isNotEmpty) {
        var highestMatch = knockoutMatches[0];
        int maxRound = int.tryParse(highestMatch['round'].toString()) ?? 1;
        for (var m in knockoutMatches) {
          int r = int.tryParse(m['round'].toString()) ?? 1;
          if (r > maxRound) {
            maxRound = r;
            highestMatch = m;
          }
        }
        finalMatch = highestMatch;
        isStageCompleted =
            finalMatch['status'] == 'completed' &&
            finalMatch['winner_id'] != null;
      }
    }

    return ScrollConfiguration(
      behavior: CustomScrollBehavior(),
      child: Container(
        decoration: const BoxDecoration(
          color: QortColors.background,
        ),
        child: Column(
          children: [
            if (_availableStages.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 15, left: 15, right: 15),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _availableStages.map((stage) {
                      final stageId =
                          TournamentBracketUtils.stageKey(stage['id']);
                      bool isSelected = stageId ==
                          TournamentBracketUtils.stageKey(_selectedStageId);
                      String division = stage['division'] ?? 'Visi';
                      String name = stage['name'] ?? 'Etapas';
                      String displayLabel = division == 'Visi'
                          ? name
                          : '$division: $name';

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF00E5FF,
                                    ).withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : [],
                        ),
                        child: ChoiceChip(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 8,
                          ),
                          label: Text(
                            displayLabel,
                            style: GoogleFonts.oswald(
                              color: isSelected
                                  ? QortColors.textPrimary
                                  : QortColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: QortColors.primaryLight,
                          backgroundColor: QortColors.surface,
                          side: BorderSide(
                            color: isSelected
                                ? QortColors.primary
                                : QortColors.border,
                          ),
                          onSelected: (val) {
                            setState(() {
                              _selectedStageId = stageId;
                              _showPodium = false;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            if (isStageCompleted && finalMatch != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: InkWell(
                  onTap: () => setState(() => _showPodium = !_showPodium),
                  borderRadius: BorderRadius.circular(15),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFDF00), Color(0xFFD4AF37)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFDF00).withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showPodium
                              ? LucideIcons.layoutTemplate
                              : LucideIcons.trophy,
                          color: Colors.black87,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _showPodium
                              ? "GRĮŽTI Į TURNYRO MEDĮ"
                              : "🏆 ŽIŪRĖTI PODIUMĄ IR REZULTATUS",
                          style: GoogleFonts.bebasNeue(
                            color: Colors.black87,
                            fontSize: 22,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Expanded(
              child: currentStageMatches.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.matches.isEmpty
                              ? "Burtai dar negeneruoti. Partner Dashboard → sugeneruokite tvarkaraštį."
                              : "Šiame etape mačų nėra. Pasirinkite kitą etapą arba sugeneruokite burtus.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: QortColors.textSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    )
                  : (_showPodium && isStageCompleted && finalMatch != null
                        ? _buildWowPodiumView(currentStageMatches, finalMatch)
                        : (isKnockout
                              ? _buildKnockoutTree(currentStageMatches)
                              : _buildGroupMatrixView(currentStageMatches))),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _calculateExactPlaces(
    List<Map<String, dynamic>> matches,
    Map<String, dynamic> finalMatch,
  ) {
    Map<String, Map<String, dynamic>> players = {};
    for (var m in matches) {
      String? p1 = m['player1_id'], p2 = m['player2_id'];
      if (p1 != null && !players.containsKey(p1)) {
        players[p1] = {
          'id': p1,
          'name': _getName(p1),
          'rp': _getEarnedRp(p1),
          'xp': _getEarnedXp(p1),
          'wins': 0,
          'losses': 0,
          'setsW': 0,
          'setsL': 0,
          'highestRound': 0,
          'exactPlace': 999,
        };
      }
      if (p2 != null && !players.containsKey(p2)) {
        players[p2] = {
          'id': p2,
          'name': _getName(p2),
          'rp': _getEarnedRp(p2),
          'xp': _getEarnedXp(p2),
          'wins': 0,
          'losses': 0,
          'setsW': 0,
          'setsL': 0,
          'highestRound': 0,
          'exactPlace': 999,
        };
      }
    }

    for (var m in matches) {
      if (m['status'] == 'completed' &&
          m['match_details']?.toString().contains('BYE') != true) {
        String? p1 = m['player1_id'],
            p2 = m['player2_id'],
            wId = m['winner_id'];
        int s1 = int.tryParse(m['score_p1'].toString()) ?? 0,
            s2 = int.tryParse(m['score_p2'].toString()) ?? 0,
            r = int.tryParse(m['round'].toString()) ?? 1;

        if (p1 != null) {
          players[p1]!['setsW'] += s1;
          players[p1]!['setsL'] += s2;
          if (r < 50 && r > players[p1]!['highestRound']) {
            players[p1]!['highestRound'] = r;
          }
          if (wId == p1) {
            players[p1]!['wins']++;
          } else {
            players[p1]!['losses']++;
          }
        }
        if (p2 != null) {
          players[p2]!['setsW'] += s2;
          players[p2]!['setsL'] += s1;
          if (r < 50 && r > players[p2]!['highestRound']) {
            players[p2]!['highestRound'] = r;
          }
          if (wId == p2) {
            players[p2]!['wins']++;
          } else {
            players[p2]!['losses']++;
          }
        }
      }
    }

    for (var m in matches) {
      if (m['status'] == 'completed' && m['winner_id'] != null) {
        String wId = m['winner_id'];
        String lId = m['player1_id'] == wId ? m['player2_id'] : m['player1_id'];
        int r = int.tryParse(m['round'].toString()) ?? 1,
            maxR = int.tryParse(finalMatch['round'].toString()) ?? 1;

        if (r == maxR) {
          players[wId]?['exactPlace'] = 1;
          players[lId]?['exactPlace'] = 2;
        } else if (r == 99) {
          players[wId]?['exactPlace'] = 3;
          players[lId]?['exactPlace'] = 4;
        } else if (r >= 100) {
          int basePlace = r - 100;
          players[wId]?['exactPlace'] = basePlace;
          players[lId]?['exactPlace'] = basePlace + 1;
        }
      }
    }

    List<Map<String, dynamic>> leaderboard = players.values.toList();
    leaderboard.sort((a, b) {
      int placeA = a['exactPlace'], placeB = b['exactPlace'];
      if (placeA != 999 || placeB != 999) return placeA.compareTo(placeB);
      int hrA = a['highestRound'], hrB = b['highestRound'];
      if (hrA != hrB) return hrB.compareTo(hrA);
      int wA = a['wins'], wB = b['wins'];
      if (wA != wB) return wB.compareTo(wA);
      int diffA = a['setsW'] - a['setsL'], diffB = b['setsW'] - b['setsL'];
      return diffB.compareTo(diffA);
    });

    return leaderboard;
  }

  Widget _buildWowPodiumView(
    List<Map<String, dynamic>> matches,
    Map<String, dynamic> finalMatch,
  ) {
    List<Map<String, dynamic>> leaderboard = _calculateExactPlaces(
      matches,
      finalMatch,
    );
    Map<String, dynamic>? p1, p2, p3;
    if (leaderboard.isNotEmpty) p1 = leaderboard[0];
    if (leaderboard.length > 1) p2 = leaderboard[1];
    if (leaderboard.length > 2 && leaderboard[2]['exactPlace'] == 3) {
      p3 = leaderboard[2];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            height: 280,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (p2 != null)
                  _build3DPodiumStep(p2['name'], 2, 130, const [
                    Color(0xFFE0E0E0),
                    Color(0xFF9E9E9E),
                  ], shadowColor: Colors.white24),
                if (p1 != null)
                  _build3DPodiumStep(
                    p1['name'],
                    1,
                    190,
                    const [Color(0xFFFFDF00), Color(0xFFD4AF37)],
                    isWinner: true,
                    shadowColor: const Color(0xFFFFDF00).withOpacity(0.5),
                  ),
                if (p3 != null)
                  _build3DPodiumStep(p3['name'], 3, 100, const [
                    Color(0xFFCD7F32),
                    Color(0xFFA0522D),
                  ], shadowColor: Colors.orange.withOpacity(0.2)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B).withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withOpacity(0.15),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: const Border(
                          bottom: BorderSide(color: Colors.white10),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 3,
                            child: Text(
                              "GALUTINĖ RIKIUOTĖ",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "W-L",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.oswald(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "SET",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.oswald(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "RP",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.oswald(
                                color: Colors.greenAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "XP",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.oswald(
                                color: Colors.purpleAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...leaderboard.asMap().entries.map((entry) {
                      int index = entry.key;
                      var p = entry.value;
                      String rankDisplay = p['exactPlace'] != 999
                          ? "${p['exactPlace']}."
                          : "${index + 1}.";
                      Color rankColor = Colors.grey;
                      if (p['exactPlace'] == 1) {
                        rankColor = const Color(0xFFFFD700);
                      }
                      if (p['exactPlace'] == 2) {
                        rankColor = const Color(0xFFE0E0E0);
                      }
                      if (p['exactPlace'] == 3) {
                        rankColor = const Color(0xFFCD7F32);
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: index % 2 == 0
                              ? Colors.transparent
                              : Colors.white.withOpacity(0.02),
                          border: const Border(
                            bottom: BorderSide(color: Colors.white10),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 30,
                                    child: Text(
                                      rankDisplay,
                                      style: GoogleFonts.bebasNeue(
                                        color: rankColor,
                                        fontSize: 18,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      p['name'],
                                      style: TextStyle(
                                        color: p['exactPlace'] <= 3
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: p['exactPlace'] <= 3
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                "${p['wins']} - ${p['losses']}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                "${p['setsW']}:${p['setsL']}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                "+${p['rp']}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                "+${p['xp']}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.purpleAccent,
                                  fontWeight: FontWeight.bold,
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
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _build3DPodiumStep(
    String name,
    int place,
    double height,
    List<Color> gradient, {
    bool isWinner = false,
    required Color shadowColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isWinner)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Icon(
                LucideIcons.crown,
                color: const Color(0xFFFFD700),
                size: 40,
                shadows: [
                  Shadow(
                    color: const Color(0xFFFFD700).withOpacity(0.8),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),
          Text(
            name,
            style: GoogleFonts.oswald(
              color: Colors.white,
              fontSize: isWinner ? 18 : 15,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(
            width: isWinner ? 100 : 85,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 25,
                  offset: const Offset(0, -5),
                  spreadRadius: isWinner ? 5 : 0,
                ),
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 10,
                  child: Container(
                    width: isWinner ? 70 : 55,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Text(
                  "$place",
                  style: GoogleFonts.bebasNeue(
                    color: Colors.black.withOpacity(0.7),
                    fontSize: isWinner ? 55 : 40,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnockoutTree(List<Map<String, dynamic>> stageMatches) {
    final rounds = TournamentBracketUtils.groupKnockoutRounds(stageMatches);
    final sortedRoundKeys = rounds.keys.toList()..sort();
    final placementMatches = stageMatches
        .where((m) => (int.tryParse(m['round'].toString()) ?? 1) >= 50)
        .toList();
    placementMatches.sort(
      (a, b) => (int.tryParse(a['round'].toString()) ?? 1).compareTo(
        int.tryParse(b['round'].toString()) ?? 1,
      ),
    );

    if (sortedRoundKeys.isEmpty && placementMatches.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Atkrintamųjų medis tuščias — patikrinkite, ar sugeneruoti burtai šiam etapui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: QortColors.textSecondary),
          ),
        ),
      );
    }

    const columnWidth = 280.0;
    const columnGap = 60.0;
    const cardVerticalPadding = 20.0;
    // _WowBracketCard: round label (~23) + 2×player row (~56) + divider (1) ≈ 136
    const estimatedCardHeight = 136.0;

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(150),
      minScale: 0.2,
      maxScale: 2.0,
      constrained: false,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BracketConnectorPainter(
                  rounds: rounds,
                  sortedRoundKeys: sortedRoundKeys,
                  columnWidth: columnWidth,
                  columnGap: columnGap,
                  cardVerticalPadding: cardVerticalPadding,
                  estimatedCardHeight: estimatedCardHeight,
                  lineColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...sortedRoundKeys.map((r) {
                  return Container(
                    width: columnWidth,
                    margin: const EdgeInsets.only(right: columnGap),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: rounds[r]!.map((match) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: cardVerticalPadding,
                          ),
                          child: _WowBracketCard(
                            match: match,
                            participants: widget.participants,
                            roundName: _getRoundName(r, rounds[r]!.length),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
                if (placementMatches.isNotEmpty)
              Container(
                width: 280,
                margin: const EdgeInsets.only(left: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.2),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: Text(
                        "PAPILDOMOS VIETOS",
                        style: GoogleFonts.bebasNeue(
                          color: Colors.orangeAccent,
                          fontSize: 24,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...placementMatches.map((match) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: _WowBracketCard(
                          match: match,
                          participants: widget.participants,
                          roundName: _getPlacementName(
                            int.tryParse(match['round'].toString()) ?? 1,
                          ),
                          isSpecial: true,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRoundName(int roundNum, int matchCount) {
    if (matchCount == 1) return "FINALAS";
    if (matchCount == 2) return "PUSFINALIS";
    if (matchCount == 4) return "KETVIRTFINALIS";
    if (matchCount == 8) return "AŠTUNTFINALIS";
    return "ETAPAS $roundNum";
  }

  String _getPlacementName(int round) {
    if (round == 99) return "DĖL 3 VIETOS";
    if (round > 100) return "DĖL ${round - 100} VIETOS";
    return "PAGUODA";
  }

  static String _groupKey(String name) {
    var s = name.trim();
    final lower = s.toLowerCase();
    if (lower.startsWith('grupė ')) {
      s = s.substring(6).trim();
    } else if (lower.startsWith('grupe ')) {
      s = s.substring(6).trim();
    }
    return s.toUpperCase();
  }

  bool _stageHasGroupMatches(List<Map<String, dynamic>> stageMatches) {
    return stageMatches.any((m) {
      final g = m['group_name']?.toString().trim();
      return g != null && g.isNotEmpty;
    });
  }

  List<String> _playerIdsForGroup(
    String groupName,
    List<Map<String, dynamic>> stageMatches,
  ) {
    final key = _groupKey(groupName);
    final ids = <String>{};
    for (final m in stageMatches) {
      final mGroup = _groupKey(m['group_name']?.toString() ?? '');
      if (mGroup != key) continue;

      final p1 = m['player1_id']?.toString();
      final p2 = m['player2_id']?.toString();
      if (p1 != null && p1.isNotEmpty) ids.add(p1);
      if (p2 != null && p2.isNotEmpty) ids.add(p2);
    }
    return ids.toList();
  }

  Widget _buildGroupMatrixView(List<Map<String, dynamic>> stageMatches) {
    if (!_stageHasGroupMatches(stageMatches)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Šis etapas neturi grupių — matrica rodoma tik grupių etapams.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: QortColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    Map<String, List<Map<String, dynamic>>> groups = {};
    for (var m in stageMatches) {
      final gName = m['group_name']?.toString().trim();
      if (gName == null || gName.isEmpty) continue;
      groups.putIfAbsent(gName, () => []).add(m);
    }
    final groupNames = groups.keys.toList()..sort();

    if (groupNames.isEmpty) {
      return const Center(
        child: Text(
          "Nėra matomų lentelių šiam etapui.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        for (int i = 0; i < groupNames.length; i++) ...[
          if (i > 0) const SizedBox(height: 24),
          TournamentGroupMatrix(
            groupName: groupNames[i],
            matches: groups[groupNames[i]]!,
            groupPlayerIds: _playerIdsForGroup(groupNames[i], stageMatches),
            currentUserId: _currentUserId,
            resolveName: (id) => _getName(id),
          ),
        ],
      ],
    );
  }
}

class _BracketConnectorPainter extends CustomPainter {
  final Map<int, List<Map<String, dynamic>>> rounds;
  final List<int> sortedRoundKeys;
  final double columnWidth;
  final double columnGap;
  final double cardVerticalPadding;
  final double estimatedCardHeight;
  final Color lineColor;

  const _BracketConnectorPainter({
    required this.rounds,
    required this.sortedRoundKeys,
    required this.columnWidth,
    required this.columnGap,
    required this.cardVerticalPadding,
    required this.estimatedCardHeight,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int rIdx = 0; rIdx < sortedRoundKeys.length - 1; rIdx++) {
      final r = sortedRoundKeys[rIdx];
      final nextR = sortedRoundKeys[rIdx + 1];
      if (r >= 50) continue;

      final matches = rounds[r]!;
      final nextMatches = rounds[nextR]!;

      for (int i = 0; i < matches.length; i++) {
        final match = matches[i];
        final p1 = match['player1_id'];
        final p2 = match['player2_id'];
        if (p1 == null && p2 == null) continue;

        final m = int.tryParse(match['match_num'].toString()) ?? (i + 1);
        final nextM = (m + 1) ~/ 2;

        final childIdx = nextMatches.indexWhere((nm) {
          final nmNum = int.tryParse(nm['match_num'].toString()) ?? -1;
          return nmNum == nextM;
        });
        if (childIdx == -1) continue;

        final parentX = rIdx * (columnWidth + columnGap) + columnWidth;
        final parentY = _matchCenterY(matches.length, i);

        final childX = (rIdx + 1) * (columnWidth + columnGap);
        final childY = _matchCenterY(nextMatches.length, childIdx);

        final midX = parentX + (columnGap / 2);
        canvas.drawLine(Offset(parentX, parentY), Offset(midX, parentY), paint);
        canvas.drawLine(Offset(midX, parentY), Offset(midX, childY), paint);
        canvas.drawLine(Offset(midX, childY), Offset(childX, childY), paint);
      }
    }
  }

  double _matchCenterY(int totalMatches, int index) {
    if (totalMatches <= 0) return 0;
    final segmentHeight =
        estimatedCardHeight + cardVerticalPadding * 2;
    return cardVerticalPadding +
        estimatedCardHeight / 2 +
        index * segmentHeight;
  }

  @override
  bool shouldRepaint(_BracketConnectorPainter old) =>
      old.rounds != rounds ||
      old.sortedRoundKeys != sortedRoundKeys ||
      old.lineColor != lineColor;
}

class _WowBracketCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final List<dynamic> participants;
  final String roundName;
  final bool isSpecial;

  const _WowBracketCard({
    required this.match,
    required this.participants,
    required this.roundName,
    this.isSpecial = false,
  });

  String? _getName(dynamic id) {
    if (id == null) return null;
    final cleanId = id.toString().trim();
    for (var p in participants) {
      if (p['user_id'].toString() == cleanId) {
        return p['team_name'] ?? "Žaidėjas";
      }
    }
    return "Žaidėjas";
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.qortPalette;
    final p1Name = _getName(match['player1_id']);
    final p2Name = _getName(match['player2_id']);
    bool isBye = (p2Name == null && match['status'] == 'completed');
    bool isWaiting = p1Name == null && p2Name == null;
    final p1 = p1Name ?? (isWaiting ? "Laukiama..." : "---");
    final p2 = isBye
        ? "BYE (Laisvas)"
        : (p2Name ?? (isWaiting ? "Laukiama..." : "---"));
    final s1 = int.tryParse(match['score_p1'].toString()) ?? 0;
    final s2 = int.tryParse(match['score_p2'].toString()) ?? 0;
    final isCompleted = match['status'] == 'completed';
    final winnerId = match['winner_id']?.toString();

    String details = match['match_details']?['score_str']?.toString() ?? "";
    if (details == "BYE") details = "";

    Color accentColor = isSpecial ? const Color(0xFFF59E0B) : palette.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            roundName,
            style: GoogleFonts.inter(
              color: palette.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isCompleted && winnerId != null)
                  ? accentColor.withValues(alpha: 0.45)
                  : palette.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: palette.isDark ? 0.15 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _playerRow(
                p1,
                s1,
                isCompleted && winnerId == match['player1_id']?.toString(),
                isWaiting || p1Name == null,
                accentColor,
                palette,
              ),
              Divider(height: 1, color: palette.border),
              _playerRow(
                p2,
                s2,
                isCompleted && winnerId == match['player2_id']?.toString(),
                isWaiting || p2Name == null || isBye,
                accentColor,
                palette,
              ),
              if (details.isNotEmpty && !isBye)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: palette.surfaceElevated,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    details,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _playerRow(
    String name,
    int score,
    bool isWinner,
    bool isPlaceholder,
    Color accentColor,
    dynamic palette,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: isWinner ? accentColor.withValues(alpha: 0.08) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (isWinner)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      LucideIcons.trophy,
                      size: 15,
                      color: accentColor,
                    ),
                  ),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.inter(
                      color: isPlaceholder
                          ? palette.textSecondary
                          : palette.textPrimary,
                      fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (!isPlaceholder && name != 'BYE (Laisvas)')
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isWinner
                    ? accentColor.withValues(alpha: 0.12)
                    : palette.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isWinner ? accentColor : palette.border,
                ),
              ),
              child: Text(
                '$score',
                style: GoogleFonts.inter(
                  color: isWinner ? accentColor : palette.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
