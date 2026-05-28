import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_palette_extension.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/query_limits.dart';

class StandingsTab extends StatefulWidget {
  final String tournamentId;
  final List<dynamic> stages;

  const StandingsTab({
    super.key,
    required this.tournamentId,
    required this.stages,
  });

  @override
  State<StandingsTab> createState() => _StandingsTabState();
}

class _StandingsTabState extends State<StandingsTab> {
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _groups = {};
  bool _allowTies = false;
  bool _isAdmin = false;

  List<Map<String, dynamic>> _groupStages = [];
  String _selectedStageId = '';

  @override
  void initState() {
    super.initState();
    _extractGroupStages();
  }

  void _extractGroupStages() {
    _groupStages = widget.stages
        .where((s) {
          String format = s['format']?.toString() ?? '';
          return format.contains('Grupės') ||
              format.contains('Swiss') ||
              format.contains('Round Robin');
        })
        .map((s) => Map<String, dynamic>.from(s))
        .toList();

    if (_groupStages.isNotEmpty) {
      _selectedStageId = _groupStages[0]['id']?.toString() ?? '';
    } else {
      _selectedStageId = 'group';
    }
    _loadStandings();
  }

  Future<void> _loadStandings() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final currentUserId = client.auth.currentUser?.id;

      final tData = await client
          .from('tournaments')
          .select('owner_id')
          .eq('id', widget.tournamentId)
          .maybeSingle();

      int winPts = 3, tiePts = 1, lossPts = 0;
      bool allowTies = false;
      bool isAdmin = false;

      if (tData != null) isAdmin = tData['owner_id'] == currentUserId;

      var currentStageData = widget.stages.firstWhere(
        (s) => s['id'] == _selectedStageId,
        orElse: () => null,
      );
      if (currentStageData != null) {
        winPts =
            int.tryParse(
              currentStageData['points_for_win']?.toString() ?? '3',
            ) ??
            3;
        tiePts =
            int.tryParse(
              currentStageData['points_for_tie']?.toString() ?? '1',
            ) ??
            1;
        lossPts =
            int.tryParse(
              currentStageData['points_for_loss']?.toString() ?? '0',
            ) ??
            0;
        allowTies = currentStageData['allow_ties'] == true;
      }

      final matches = await client
          .from('matches')
          .select()
          .eq('tournament_id', widget.tournamentId)
          .eq('stage', _selectedStageId)
          .limit(QueryLimits.tournamentMatches);
      final participants = await client
          .from('tournament_participants')
          .select()
          .eq('tournament_id', widget.tournamentId)
          .limit(QueryLimits.tournamentParticipants);

      Map<String, List<Map<String, dynamic>>> tempGroups = {};
      Map<String, Map<String, dynamic>> playerStats = {};

      for (var p in participants) {
        String pId = p['user_id'];
        playerStats[pId] = {
          'db_id': p['id'],
          'user_id': pId,
          'name': p['team_name'] ?? "Žaidėjas",
          'group_name': p['group_name'] ?? 'A',
          'manual_rank': p['manual_rank'],
          'played': 0,
          'won': 0,
          'drawn': 0,
          'lost': 0,
          'sets_won': 0,
          'sets_lost': 0,
          'points': 0,
          'h2h_points': 0,
          'h2h_sets_diff': 0,
        };
      }

      for (var m in matches) {
        String groupName = m['group_name'] ?? 'A';
        String? p1 = m['player1_id'], p2 = m['player2_id'];

        if (p1 != null && playerStats.containsKey(p1)) {
          playerStats[p1]!['group_name'] = groupName;
        }
        if (p2 != null && playerStats.containsKey(p2)) {
          playerStats[p2]!['group_name'] = groupName;
        }

        if (m['status'] != 'completed') continue;

        String? wId = m['winner_id'];
        if (p1 == null ||
            p2 == null ||
            !playerStats.containsKey(p1) ||
            !playerStats.containsKey(p2)) {
          continue;
        }

        int s1 = int.tryParse(m['score_p1']?.toString() ?? '0') ?? 0;
        int s2 = int.tryParse(m['score_p2']?.toString() ?? '0') ?? 0;

        playerStats[p1]!['played'] += 1;
        playerStats[p2]!['played'] += 1;
        playerStats[p1]!['sets_won'] += s1;
        playerStats[p1]!['sets_lost'] += s2;
        playerStats[p2]!['sets_won'] += s2;
        playerStats[p2]!['sets_lost'] += s1;

        if (wId == p1) {
          playerStats[p1]!['won'] += 1;
          playerStats[p1]!['points'] += winPts;
          playerStats[p2]!['lost'] += 1;
          playerStats[p2]!['points'] += lossPts;
        } else if (wId == p2) {
          playerStats[p2]!['won'] += 1;
          playerStats[p2]!['points'] += winPts;
          playerStats[p1]!['lost'] += 1;
          playerStats[p1]!['points'] += lossPts;
        } else {
          if (allowTies) {
            playerStats[p1]!['drawn'] += 1;
            playerStats[p2]!['drawn'] += 1;
            playerStats[p1]!['points'] += tiePts;
            playerStats[p2]!['points'] += tiePts;
          }
        }
      }

      playerStats.forEach((key, stats) {
        String group = stats['group_name'] ?? 'A';
        bool hasMatchesInThisStage = matches.any(
          (m) => m['player1_id'] == key || m['player2_id'] == key,
        );
        if (hasMatchesInThisStage) {
          if (!tempGroups.containsKey(group)) tempGroups[group] = [];
          tempGroups[group]!.add(stats);
        }
      });

      tempGroups.forEach((groupName, players) {
        Map<int, List<Map<String, dynamic>>> pointGroups = {};
        for (var p in players) {
          pointGroups.putIfAbsent(p['points'] as int, () => []).add(p);
        }

        for (var tiedPlayers in pointGroups.values) {
          if (tiedPlayers.length > 1) {
            List<String> tiedIds = tiedPlayers
                .map((p) => p['user_id'].toString())
                .toList();
            for (var m in matches) {
              if (m['status'] == 'completed') {
                String? p1 = m['player1_id'], p2 = m['player2_id'];
                if (p1 != null &&
                    p2 != null &&
                    tiedIds.contains(p1) &&
                    tiedIds.contains(p2)) {
                  String? wId = m['winner_id'];
                  int s1 = int.tryParse(m['score_p1']?.toString() ?? '0') ?? 0;
                  int s2 = int.tryParse(m['score_p2']?.toString() ?? '0') ?? 0;

                  playerStats[p1]!['h2h_sets_diff'] += (s1 - s2);
                  playerStats[p2]!['h2h_sets_diff'] += (s2 - s1);
                  if (wId == p1) {
                    playerStats[p1]!['h2h_points'] += winPts;
                  } else if (wId == p2)
                    playerStats[p2]!['h2h_points'] += winPts;
                  else if (allowTies) {
                    playerStats[p1]!['h2h_points'] += tiePts;
                    playerStats[p2]!['h2h_points'] += tiePts;
                  }
                }
              }
            }
          }
        }

        players.sort((a, b) {
          if (a['manual_rank'] != null || b['manual_rank'] != null) {
            int mrA = a['manual_rank'] ?? 999, mrB = b['manual_rank'] ?? 999;
            if (mrA != mrB) return mrA.compareTo(mrB);
          }
          int ptA = a['points'] as int, ptB = b['points'] as int;
          if (ptB != ptA) return ptB.compareTo(ptA);
          int h2hA = a['h2h_points'] as int, h2hB = b['h2h_points'] as int;
          if (h2hA != h2hB) return h2hB.compareTo(h2hA);
          int h2hDiffA = a['h2h_sets_diff'] as int,
              h2hDiffB = b['h2h_sets_diff'] as int;
          if (h2hDiffA != h2hDiffB) return h2hDiffB.compareTo(h2hDiffA);
          int diffA = (a['sets_won'] as int) - (a['sets_lost'] as int);
          int diffB = (b['sets_won'] as int) - (b['sets_lost'] as int);
          if (diffB != diffA) return diffB.compareTo(diffA);
          return (b['sets_won'] as int).compareTo(a['sets_won'] as int);
        });
      });

      if (mounted) {
        setState(() {
          _groups = tempGroups;
          _allowTies = allowTies;
          _isAdmin = isAdmin;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showReorderDialog(
    String groupName,
    List<Map<String, dynamic>> players,
  ) {
    List<Map<String, dynamic>> reorderablePlayers = List.from(players);

    showDialog(
      context: context,
      builder: (ctx) {
        final palette = context.qortPalette;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: palette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: palette.border),
              ),
              title: Text(
                "Koreguoti: Grupė $groupName",
                style: GoogleFonts.inter(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: Column(
                  children: [
                    const Text(
                      "Vilkite (Drag & Drop) žaidėjus į norimas pozicijas.",
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: reorderablePlayers.length,
                        onReorder: (oldIndex, newIndex) {
                          setDialogState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = reorderablePlayers.removeAt(oldIndex);
                            reorderablePlayers.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final p = reorderablePlayers[index];
                          return Card(
                            key: ValueKey(p['db_id']),
                            color: palette.surfaceElevated,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Text(
                                "${index + 1}.",
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              title: Text(
                                p['name'],
                                style: TextStyle(color: palette.textPrimary),
                              ),
                              trailing: Icon(
                                LucideIcons.gripVertical,
                                color: palette.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    try {
                      for (var p in players) {
                        await Supabase.instance.client
                            .from('tournament_participants')
                            .update({'manual_rank': null})
                            .eq('id', p['db_id']);
                      }
                      await _loadStandings();
                    } catch (e) {}
                  },
                  child: const Text(
                    "Atstatyti",
                    style: TextStyle(color: QortColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    try {
                      for (int i = 0; i < reorderablePlayers.length; i++) {
                        await Supabase.instance.client
                            .from('tournament_participants')
                            .update({'manual_rank': i + 1})
                            .eq('id', reorderablePlayers[i]['db_id']);
                      }
                      await _loadStandings();
                    } catch (e) {}
                  },
                  child: const Text(
                    "IŠSAUGOTI",
                    style: TextStyle(color: QortColors.textPrimary),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: context.qortPalette.primary),
      );
    }
    final palette = context.qortPalette;
    final groupNames = _groups.keys.toList()..sort();

    return Column(
      children: [
        if (_groupStages.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 15, left: 15, right: 15),
            child: SizedBox(
              width: double.infinity,
              // NAUDOJAM WRAP KAD KORTELĖS VISADA BŪTŲ MATOMOS EKRANE
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _groupStages.map((stage) {
                  bool isSelected = stage['id'] == _selectedStageId;
                  String division = stage['division'] ?? 'Visi';
                  String name = stage['name'] ?? 'Etapas';
                  String displayLabel = division == 'Visi'
                      ? name
                      : '$division: $name';

                  return ChoiceChip(
                    label: Text(
                      displayLabel,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : palette.chipUnselectedText,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: palette.primary,
                    backgroundColor: palette.chipUnselectedBg,
                    side: BorderSide(
                      color: isSelected ? palette.primary : palette.border,
                    ),
                    onSelected: (val) {
                      setState(() => _selectedStageId = stage['id']);
                      _loadStandings();
                    },
                  );
                }).toList(),
              ),
            ),
          ),

        if (_groups.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                "Šiame etape nėra duomenų. Laukite varžybų pradžios.",
                style: TextStyle(color: QortColors.textSecondary),
              ),
            ),
          ),

        if (_groups.isNotEmpty)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: groupNames.length,
              itemBuilder: (context, index) {
                String gName = groupNames[index];
                List<Map<String, dynamic>> players = _groups[gName]!;
                String displayGroupName = gName.toUpperCase();
                if (!displayGroupName.contains("GRUPĖ")) {
                  displayGroupName = "GRUPĖ $displayGroupName";
                }
                bool hasManualOverrides = players.any(
                  (p) => p['manual_rank'] != null,
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasManualOverrides
                          ? Colors.orange.withValues(alpha: 0.45)
                          : palette.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: palette.isDark ? 0.12 : 0.04,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: hasManualOverrides
                              ? Colors.orange.withValues(alpha: 0.08)
                              : palette.surfaceElevated,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                          border: Border(bottom: BorderSide(color: palette.border)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayGroupName,
                                  style: GoogleFonts.inter(
                                    color: palette.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                if (hasManualOverrides)
                                  const Text(
                                    "Rikiuotė koreguota rankiniu būdu",
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                            if (_isAdmin)
                              IconButton(
                                icon: const Icon(
                                  LucideIcons.edit3,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _showReorderDialog(gName, players),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(3),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1),
                            3: FlexColumnWidth(1),
                            4: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: palette.border),
                                ),
                              ),
                              children: [
                                _th("ŽAIDĖJAS", palette),
                                _th("SUŽ.", palette, center: true),
                                _th(_allowTies ? "W-D-L" : "W-L", palette,
                                    center: true),
                                _th("SET", palette, center: true),
                                _th("TAŠKAI", palette, center: true, isAccent: true),
                              ],
                            ),
                            ...players.asMap().entries.map((entry) {
                              int rank = entry.key + 1;
                              var player = entry.value;
                              return TableRow(
                                decoration: BoxDecoration(
                                  color: rank.isOdd
                                      ? palette.listRowAlt.withValues(alpha: 0.5)
                                      : null,
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          "$rank. ",
                                          style: TextStyle(
                                            color: palette.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            player['name'],
                                            style: TextStyle(
                                              color: palette.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _td(player['played'].toString(), palette),
                                  _td(
                                    _allowTies
                                        ? "${player['won']}-${player['drawn']}-${player['lost']}"
                                        : "${player['won']}-${player['lost']}",
                                    palette,
                                  ),
                                  _td(
                                    "${player['sets_won']}:${player['sets_lost']}",
                                    palette,
                                  ),
                                  _td(
                                    player['points'].toString(),
                                    palette,
                                    isAccent: true,
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _th(
    String title,
    dynamic palette, {
    bool center = false,
    bool isAccent = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: GoogleFonts.inter(
          color: isAccent ? palette.primary : palette.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _td(String text, dynamic palette, {bool isAccent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isAccent ? palette.primary : palette.textSecondary,
          fontWeight: isAccent ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}
