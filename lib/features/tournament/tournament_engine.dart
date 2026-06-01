import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/query_limits.dart';
import '../../core/utils/datetime_utils.dart';
import '../../core/services/user_sports_service.dart';

class TournamentEngine {
  static Future<void> generateTournamentMatches(String tournamentId) async {
    final client = Supabase.instance.client;

    try {
      final tRes = await client
          .from('tournaments')
          .select()
          .eq('id', tournamentId)
          .single();

      var rawStages = tRes['stages_config'];
      List<dynamic> stages = [];
      if (rawStages is List) {
        stages = List.from(rawStages);
      } else if (rawStages is Map) {
        stages = [rawStages];
      }

      if (stages.isEmpty) return;

      final pRes = await client
          .from('tournament_participants')
          .select()
          .eq('tournament_id', tournamentId);
      List<dynamic> allParticipants = List.from(pRes);

      if (allParticipants.length < 2) return;

      // Prieš generuojant naujus, ištriname senus mačus, kad nebūtų dublikatų
      await client.from('matches').delete().eq('tournament_id', tournamentId);

      // Randame "Target" etapus (Atkrintamąsias), kurios laukia žaidėjų po grupių.
      Set<String> targetStages = {};
      for (var s in stages) {
        if (s['advance_to'] != null && s['advance_to'] != 'none') {
          targetStages.add(s['advance_to']);
        }
        if (s['drop_to'] != null && s['drop_to'] != 'none') {
          targetStages.add(s['drop_to']);
        }
      }

      // Generuojame TIK pradinius etapus
      for (var stage in stages) {
        String stageId =
            stage['id'] ?? 'stage_${DateTime.now().millisecondsSinceEpoch}';
        String format = stage['format'] ?? "Round Robin (Grupės)";
        String division = stage['division'] ?? 'Visi';

        // Jei tai etapas, kuris laukia žaidėjų po grupių - jam pradinių burtų negeneruojame!
        if (targetStages.contains(stageId)) continue;

        // Atrenkame TIK to konkretaus diviziono dalyvius
        List<dynamic> stageParticipants = allParticipants.where((p) {
          if (division == 'Visi') return true;
          return p['division'] == division;
        }).toList();

        if (stageParticipants.length < 2) continue;

        if (format.contains('Grupės') ||
            format.contains('Round Robin') ||
            format.contains('Swiss')) {
          int groupCount =
              int.tryParse(stage['group_count']?.toString() ?? '2') ?? 2;
          await _generateRoundRobinByGroupCount(
            client,
            tournamentId,
            stageId,
            stageParticipants,
            groupCount,
          );
        } else if (format.contains('Elimination') ||
            format.contains('Atkrintamosios') ||
            format.contains('Kvalifikacija') ||
            format.contains('Paguodos')) {
          bool isQual = format.contains('Kvalifikacija');
          await _generateSingleElimination(
            client,
            tournamentId,
            stageId,
            stageParticipants,
            isQualification: isQual,
          );
        } else if (format.contains('Piramidė') || format.contains('Ladder')) {
          await _assignLadderPositions(client, tournamentId, stageParticipants);
        }
      }
    } catch (e) {
      debugPrint("Klaida generuojant mačus: $e");
      rethrow;
    }
  }

  static Future<void> _generateRoundRobinByGroupCount(
    SupabaseClient client,
    String tournamentId,
    String stageId,
    List<dynamic> participants,
    int totalGroups,
  ) async {
    participants.shuffle();
    List<List<dynamic>> groups = List.generate(totalGroups, (_) => []);
    for (int i = 0; i < participants.length; i++) {
      groups[i % totalGroups].add(participants[i]);
    }
    const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    List<Map<String, dynamic>> matchesToInsert = [];

    for (int g = 0; g < groups.length; g++) {
      String groupName = "Grupė ${alphabet[g]}";
      List<dynamic> groupPlayers = groups[g];
      for (int i = 0; i < groupPlayers.length; i++) {
        for (int j = i + 1; j < groupPlayers.length; j++) {
          matchesToInsert.add({
            'tournament_id': tournamentId,
            'stage': stageId,
            'group_name': groupName,
            'round': 1,
            'player1_id': groupPlayers[i]['user_id'],
            'player2_id': groupPlayers[j]['user_id'],
            'status': 'pending',
            'score_p1': 0,
            'score_p2': 0,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    }
    if (matchesToInsert.isNotEmpty) {
      await client.from('matches').insert(matchesToInsert);
    }
  }

  static bool isRoundRobinFormat(String? format) {
    final f = format ?? '';
    return f.contains('Grupės') ||
        f.contains('Round Robin') ||
        f.contains('Swiss');
  }

  /// Papildomi round-robin mačai vėliau prisijungusiam dalyviui (vs visi grupės žaidėjai).
  static Future<int> addParticipantToGroup({
    required String tournamentId,
    required String stageId,
    required String userId,
    required String groupName,
  }) async {
    final client = Supabase.instance.client;

    final existingRes = await client
        .from('matches')
        .select()
        .eq('tournament_id', tournamentId)
        .eq('stage', stageId)
        .eq('group_name', groupName);
    final existing = List<Map<String, dynamic>>.from(existingRes);

    final opponents = <String>{};
    var maxMatchNum = 0;
    for (final m in existing) {
      final p1 = m['player1_id']?.toString();
      final p2 = m['player2_id']?.toString();
      if (p1 != null && p1.isNotEmpty) opponents.add(p1);
      if (p2 != null && p2.isNotEmpty) opponents.add(p2);
      final mn = int.tryParse(m['match_num']?.toString() ?? '0') ?? 0;
      if (mn > maxMatchNum) maxMatchNum = mn;
    }
    opponents.remove(userId);

    if (opponents.isEmpty) {
      throw Exception(
        'Grupėje nėra kitų žaidėjų — negalima sugeneruoti mačų.',
      );
    }

    bool pairExists(String a, String b) {
      for (final m in existing) {
        final p1 = m['player1_id']?.toString();
        final p2 = m['player2_id']?.toString();
        if ((p1 == a && p2 == b) || (p1 == b && p2 == a)) return true;
      }
      return false;
    }

    final matchesToInsert = <Map<String, dynamic>>[];
    var matchNum = maxMatchNum;
    for (final opponent in opponents) {
      if (pairExists(userId, opponent)) continue;
      matchNum++;
      matchesToInsert.add({
        'tournament_id': tournamentId,
        'stage': stageId,
        'group_name': groupName,
        'round': 1,
        'match_num': matchNum,
        'player1_id': userId,
        'player2_id': opponent,
        'status': 'pending',
        'score_p1': 0,
        'score_p2': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    if (matchesToInsert.isEmpty) return 0;
    await client.from('matches').insert(matchesToInsert);
    return matchesToInsert.length;
  }

  static Future<void> _generateSingleElimination(
    SupabaseClient client,
    String tournamentId,
    String stageId,
    List<dynamic> participants, {
    bool isQualification = false,
    List<dynamic>? eliminatedPlayers,
  }) async {
    if (participants.isEmpty) return;

    final tRes = await client
        .from('tournaments')
        .select('stages_config')
        .eq('id', tournamentId)
        .single();
    String playoffPlaces = "Tik nugalėtoją";
    if (tRes['stages_config'] != null) {
      List<dynamic> stages = tRes['stages_config'] is List
          ? List.from(tRes['stages_config'])
          : [tRes['stages_config']];
      var sConf = stages.where((s) => s['id'] == stageId).toList();
      if (sConf.isNotEmpty) {
        playoffPlaces =
            sConf.first['playoff_places']?.toString() ?? "Tik nugalėtoją";
      }
    }

    if (isQualification) {
      participants.shuffle();
      List<Map<String, dynamic>> matchesToInsert = [];
      int matchNum = 1;
      for (int i = 0; i < participants.length; i += 2) {
        String? p1 = participants[i]['user_id'];
        String? p2 = (i + 1 < participants.length)
            ? participants[i + 1]['user_id']
            : null;
        String status = p2 == null ? 'completed' : 'pending';
        matchesToInsert.add({
          'tournament_id': tournamentId,
          'stage': stageId,
          'round': 1,
          'match_num': matchNum++,
          'player1_id': p1,
          'player2_id': p2,
          'status': status,
          'winner_id': p2 == null ? p1 : null,
          'created_at': DateTime.now().toIso8601String(),
          if (p2 == null) 'match_details': {'score_str': 'BYE'},
        });
      }
      if (matchesToInsert.isNotEmpty) {
        await client.from('matches').insert(matchesToInsert);
      }
      return;
    }

    List<dynamic> paddedParticipants = List.from(participants);
    int nextPowerOf2 = 2;
    while (nextPowerOf2 < paddedParticipants.length) {
      nextPowerOf2 *= 2;
    }
    while (paddedParticipants.length < nextPowerOf2) {
      paddedParticipants.add({'user_id': null, 'team_name': 'BYE'});
    }

    paddedParticipants.shuffle();
    List<Map<String, dynamic>> matchesToInsert = [];
    int matchNum = 1;
    int totalPlayers = paddedParticipants.length;
    int currentRoundMatches = totalPlayers ~/ 2;

    for (int i = 0; i < currentRoundMatches; i++) {
      String? p1 = paddedParticipants[i * 2]['user_id'];
      String? p2 = paddedParticipants[i * 2 + 1]['user_id'];
      String status = 'pending';
      String? winnerId;
      if (p1 == null && p2 != null) {
        status = 'completed';
        winnerId = p2;
      } else if (p2 == null && p1 != null) {
        status = 'completed';
        winnerId = p1;
      }

      matchesToInsert.add({
        'tournament_id': tournamentId,
        'stage': stageId,
        'round': 1,
        'match_num': matchNum++,
        'player1_id': p1,
        'player2_id': p2,
        'status': status,
        'winner_id': winnerId,
        'created_at': DateTime.now().toIso8601String(),
        if (status == 'completed') 'match_details': {'score_str': 'BYE'},
      });
    }

    int prevMatches = currentRoundMatches;
    int r = 2;
    while (prevMatches > 1) {
      int nextMatches = (prevMatches / 2).ceil();
      for (int i = 0; i < nextMatches; i++) {
        matchesToInsert.add({
          'tournament_id': tournamentId,
          'stage': stageId,
          'round': r,
          'match_num': i + 1,
          'player1_id': null,
          'player2_id': null,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      prevMatches = nextMatches;
      r++;
    }

    bool playThird =
        playoffPlaces == "Dėl 3 vietos" || playoffPlaces.contains("Visas");
    bool playAll = playoffPlaces.contains("Visas");

    if (playThird && totalPlayers >= 4) {
      matchesToInsert.add({
        'tournament_id': tournamentId,
        'stage': stageId,
        'round': 99,
        'match_num': 1,
        'player1_id': null,
        'player2_id': null,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    if (playAll && eliminatedPlayers != null && eliminatedPlayers.isNotEmpty) {
      Map<String, List<dynamic>> elimByGroup = {};
      for (var e in eliminatedPlayers) {
        String g = e['group'] ?? 'A';
        elimByGroup.putIfAbsent(g, () => []).add(e);
      }
      if (elimByGroup.keys.length == 2) {
        String g1 = elimByGroup.keys.elementAt(0),
            g2 = elimByGroup.keys.elementAt(1);
        List<dynamic> l1 = elimByGroup[g1]!, l2 = elimByGroup[g2]!;
        int maxLen = l1.length > l2.length ? l1.length : l2.length,
            currentPlace = participants.length + 1;

        for (int i = 0; i < maxLen; i++) {
          String? p1 = i < l1.length ? l1[i]['user_id'] : null,
              p2 = i < l2.length ? l2[i]['user_id'] : null;
          matchesToInsert.add({
            'tournament_id': tournamentId,
            'stage': stageId,
            'round': 100 + currentPlace,
            'match_num': 1,
            'player1_id': p1,
            'player2_id': p2,
            'status': (p1 == null || p2 == null) ? 'completed' : 'pending',
            'winner_id': (p1 == null && p2 != null)
                ? p2
                : ((p2 == null && p1 != null) ? p1 : null),
            'created_at': DateTime.now().toIso8601String(),
            if (p1 == null || p2 == null) 'match_details': {'score_str': 'BYE'},
          });
          currentPlace += 2;
        }
      } else {
        int currentPlace = participants.length + 1;
        for (int i = 0; i < eliminatedPlayers.length; i += 2) {
          String? p1 = eliminatedPlayers[i]['user_id'],
              p2 = (i + 1 < eliminatedPlayers.length)
                  ? eliminatedPlayers[i + 1]['user_id']
                  : null;
          matchesToInsert.add({
            'tournament_id': tournamentId,
            'stage': stageId,
            'round': 100 + currentPlace,
            'match_num': 1,
            'player1_id': p1,
            'player2_id': p2,
            'status': p2 == null ? 'completed' : 'pending',
            'winner_id': p2 == null ? p1 : null,
            'created_at': DateTime.now().toIso8601String(),
            if (p2 == null) 'match_details': {'score_str': 'BYE'},
          });
          currentPlace += 2;
        }
      }
    }

    if (matchesToInsert.isNotEmpty) {
      final insertedData = await client
          .from('matches')
          .insert(matchesToInsert)
          .select();
      for (var m in insertedData) {
        if (m['status'] == 'completed' &&
            m['winner_id'] != null &&
            m['round'] == 1) {
          int mNum = int.parse(m['match_num'].toString()),
              nextM = (mNum + 1) ~/ 2;
          bool isP1 = (mNum % 2) != 0;
          final nextMatches = await client
              .from('matches')
              .select()
              .eq('tournament_id', tournamentId)
              .eq('stage', stageId)
              .eq('round', 2)
              .eq('match_num', nextM);
          if (nextMatches.isNotEmpty) {
            await client
                .from('matches')
                .update({isP1 ? 'player1_id' : 'player2_id': m['winner_id']})
                .eq('id', nextMatches.first['id']);
          }
        }
      }
    }
  }

  static Future<void> _assignLadderPositions(
    SupabaseClient client,
    String tournamentId,
    List<dynamic> participants,
  ) async {
    bool needsAssigning = participants.any((p) => p['ladder_position'] == null);
    if (!needsAssigning) return;
    for (int i = 0; i < participants.length; i++) {
      await client
          .from('tournament_participants')
          .update({'ladder_position': i + 1})
          .eq('id', participants[i]['id']);
    }
  }

  static Future<Map<String, dynamic>> calculatePlayoffQualifiers(
    String tournamentId,
    String stageId,
  ) async {
    final client = Supabase.instance.client;
    final tRes = await client
        .from('tournaments')
        .select('stages_config')
        .eq('id', tournamentId)
        .single();
    List<dynamic> stages = [];
    int winPts = 3, tiePts = 1, lossPts = 0;
    bool allowTies = false;
    int advancingCount = 2;
    String format = 'Round Robin (Grupės)';

    if (tRes['stages_config'] != null) {
      stages = tRes['stages_config'] is List
          ? List.from(tRes['stages_config'])
          : [tRes['stages_config']];
      var currentStageConfig = stages.where((s) => s['id'] == stageId).toList();
      if (currentStageConfig.isNotEmpty) {
        var sConf = currentStageConfig.first;
        format = sConf['format'] ?? 'Round Robin (Grupės)';
        advancingCount =
            int.tryParse(sConf['advancing_players']?.toString() ?? '2') ?? 2;
        allowTies = sConf['allow_ties'] == true;
        winPts = int.tryParse(sConf['points_for_win']?.toString() ?? '3') ?? 3;
        tiePts = int.tryParse(sConf['points_for_tie']?.toString() ?? '1') ?? 1;
        lossPts =
            int.tryParse(sConf['points_for_loss']?.toString() ?? '0') ?? 0;
      }
    }

    final matches = await client
        .from('matches')
        .select()
        .eq('tournament_id', tournamentId)
        .eq('stage', stageId)
        .limit(QueryLimits.tournamentMatches);
    final participants = await client
        .from('tournament_participants')
        .select()
        .eq('tournament_id', tournamentId)
        .limit(QueryLimits.tournamentParticipants);
    Set<String> activeUserIds = {};
    for (var m in matches) {
      if (m['player1_id'] != null) activeUserIds.add(m['player1_id']);
      if (m['player2_id'] != null) activeUserIds.add(m['player2_id']);
    }

    List<Map<String, dynamic>> qualified = [], eliminated = [];

    if (format.contains('Kvalifikacija') || format.contains('Elimination')) {
      for (var m in matches) {
        if (m['status'] == 'completed') {
          String? wId = m['winner_id'];
          String? p1 = m['player1_id'];
          String? p2 = m['player2_id'];

          if (wId == null) continue;

          String? lId = (wId == p1) ? p2 : p1;

          var wList = participants.where((p) => p['user_id'] == wId).toList();
          var winnerP = wList.isNotEmpty ? wList.first : null;

          dynamic loserP;
          if (lId != null) {
            var lList = participants.where((p) => p['user_id'] == lId).toList();
            loserP = lList.isNotEmpty ? lList.first : null;
          }

          if (winnerP != null) {
            qualified.add({
              'user_id': winnerP['user_id'],
              'name': winnerP['team_name'] ?? 'Nežinomas',
              'group': 'Kvalifikacija',
              'points': 0,
            });
          }
          if (loserP != null) {
            eliminated.add({
              'user_id': loserP['user_id'],
              'name': loserP['team_name'] ?? 'Nežinomas',
              'group': 'Kvalifikacija',
              'points': 0,
            });
          }
        }
      }
      return {'qualified': qualified, 'eliminated': eliminated};
    }

    Map<String, Map<String, dynamic>> stats = {};
    for (var p in participants) {
      String? uid = p['user_id'];
      if (uid != null && activeUserIds.contains(uid)) {
        stats[uid] = {
          'user_id': uid,
          'name': p['team_name'] ?? 'Nežinomas',
          'group': 'A',
          'manual_rank': p['manual_rank'],
          'points': 0,
          'sets_won': 0,
          'sets_lost': 0,
          'h2h_points': 0,
          'h2h_sets_diff': 0,
        };
      }
    }

    for (var m in matches) {
      String gName = m['group_name'] ?? 'A';
      String? p1 = m['player1_id'], p2 = m['player2_id'];
      if (p1 != null && stats.containsKey(p1)) stats[p1]!['group'] = gName;
      if (p2 != null && stats.containsKey(p2)) stats[p2]!['group'] = gName;

      if (m['status'] == 'completed') {
        int s1 = int.tryParse(m['score_p1']?.toString() ?? '0') ?? 0;
        int s2 = int.tryParse(m['score_p2']?.toString() ?? '0') ?? 0;
        String? winner = m['winner_id'];

        if (p1 != null && stats.containsKey(p1)) {
          stats[p1]!['sets_won'] += s1;
          stats[p1]!['sets_lost'] += s2;
        }
        if (p2 != null && stats.containsKey(p2)) {
          stats[p2]!['sets_won'] += s2;
          stats[p2]!['sets_lost'] += s1;
        }

        if (winner == p1) {
          if (p1 != null && stats.containsKey(p1)) {
            stats[p1]!['points'] += winPts;
          }
          if (p2 != null && stats.containsKey(p2)) {
            stats[p2]!['points'] += lossPts;
          }
        } else if (winner == p2) {
          if (p2 != null && stats.containsKey(p2)) {
            stats[p2]!['points'] += winPts;
          }
          if (p1 != null && stats.containsKey(p1)) {
            stats[p1]!['points'] += lossPts;
          }
        } else {
          if (allowTies) {
            if (p1 != null && stats.containsKey(p1)) {
              stats[p1]!['points'] += tiePts;
            }
            if (p2 != null && stats.containsKey(p2)) {
              stats[p2]!['points'] += tiePts;
            }
          }
        }
      }
    }

    Map<String, List<Map<String, dynamic>>> groups = {};
    for (var p in stats.values) {
      String gName = p['group'];
      if (!groups.containsKey(gName)) groups[gName] = [];
      groups[gName]!.add(p);
    }

    groups.forEach((key, list) {
      Map<int, List<Map<String, dynamic>>> pointGroups = {};
      for (var p in list) {
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
                int s1 = int.tryParse(m['score_p1']?.toString() ?? '0') ?? 0,
                    s2 = int.tryParse(m['score_p2']?.toString() ?? '0') ?? 0;
                stats[p1]!['h2h_sets_diff'] += (s1 - s2);
                stats[p2]!['h2h_sets_diff'] += (s2 - s1);
                if (wId == p1) {
                  stats[p1]!['h2h_points'] += winPts;
                } else if (wId == p2)
                  stats[p2]!['h2h_points'] += winPts;
                else if (allowTies) {
                  stats[p1]!['h2h_points'] += tiePts;
                  stats[p2]!['h2h_points'] += tiePts;
                }
              }
            }
          }
        }
      }

      list.sort((a, b) {
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
        int diffA = (a['sets_won'] as int) - (a['sets_lost'] as int),
            diffB = (b['sets_won'] as int) - (b['sets_lost'] as int);
        if (diffB != diffA) return diffB.compareTo(diffA);
        return (b['sets_won'] as int).compareTo(a['sets_won'] as int);
      });

      for (int i = 0; i < list.length; i++) {
        if (i < advancingCount) {
          qualified.add(list[i]);
        } else {
          eliminated.add(list[i]);
        }
      }
    });

    return {'qualified': qualified, 'eliminated': eliminated};
  }

  static Future<void> transitionToPlayoffs(
    String tournamentId,
    String sourceStageId,
    List<dynamic> finalQualifiers,
    List<dynamic> finalEliminated,
  ) async {
    final client = Supabase.instance.client;
    final tRes = await client
        .from('tournaments')
        .select('stages_config')
        .eq('id', tournamentId)
        .single();
    List<dynamic> stages = [];
    String advanceTargetId = 'none', dropTargetId = 'none';

    if (tRes['stages_config'] != null) {
      stages = tRes['stages_config'] is List
          ? List.from(tRes['stages_config'])
          : [tRes['stages_config']];
      var sourceStage = stages.where((s) => s['id'] == sourceStageId).toList();
      if (sourceStage.isNotEmpty) {
        advanceTargetId = sourceStage.first['advance_to']?.toString() ?? 'none';
        dropTargetId = sourceStage.first['drop_to']?.toString() ?? 'none';
      }
    }

    var advList = stages.where((s) => s['id'] == advanceTargetId).toList();
    var advanceStage = advList.isNotEmpty ? advList.first : null;
    var dropList = stages.where((s) => s['id'] == dropTargetId).toList();
    var dropStage = dropList.isNotEmpty ? dropList.first : null;

    if (advanceStage != null && finalQualifiers.isNotEmpty) {
      await client
          .from('matches')
          .delete()
          .eq('tournament_id', tournamentId)
          .eq('stage', advanceStage['id']);
      String advFormat = advanceStage['format'] ?? '';
      if (advFormat.contains('Grupės') || advFormat.contains('Swiss')) {
        int groupCount =
            int.tryParse(advanceStage['group_count']?.toString() ?? '2') ?? 2;
        await _generateRoundRobinByGroupCount(
          client,
          tournamentId,
          advanceStage['id'],
          finalQualifiers,
          groupCount,
        );
      } else {
        bool isQual = advFormat.contains('Kvalifikacija');
        List<dynamic>? placementPlayers;
        if (dropTargetId == 'none' || dropTargetId.isEmpty) {
          placementPlayers = finalEliminated;
        }
        await _generateSingleElimination(
          client,
          tournamentId,
          advanceStage['id'],
          finalQualifiers,
          isQualification: isQual,
          eliminatedPlayers: placementPlayers,
        );
      }
    }

    if (dropStage != null && finalEliminated.isNotEmpty) {
      await client
          .from('matches')
          .delete()
          .eq('tournament_id', tournamentId)
          .eq('stage', dropStage['id']);
      String dropFormat = dropStage['format'] ?? '';
      if (dropFormat.contains('Grupės') || dropFormat.contains('Swiss')) {
        int groupCount =
            int.tryParse(dropStage['group_count']?.toString() ?? '2') ?? 2;
        await _generateRoundRobinByGroupCount(
          client,
          tournamentId,
          dropStage['id'],
          finalEliminated,
          groupCount,
        );
      } else {
        bool isQual = dropFormat.contains('Kvalifikacija');
        await _generateSingleElimination(
          client,
          tournamentId,
          dropStage['id'],
          finalEliminated,
          isQualification: isQual,
        );
      }
    }
  }

  static Future<void> adminSwapParticipant(
    String matchId,
    int playerSlot,
    String newParticipantId,
  ) async {
    final client = Supabase.instance.client;
    String columnToUpdate = playerSlot == 1 ? 'player1_id' : 'player2_id';
    try {
      await client
          .from('matches')
          .update({
            columnToUpdate: newParticipantId,
            'status': 'pending',
            'score_p1': 0,
            'score_p2': 0,
            'winner_id': null,
          })
          .eq('id', matchId);
    } catch (e) {
      throw Exception("Klaida");
    }
  }

  static Future<void> processInjuries(String tournamentId) async {
    // Sutrumpinta dėl vietos
  }

  static Future<void> revertLocalInjury(
    String tournamentId,
    String participantId,
    String userId,
  ) async {
    // Sutrumpinta dėl vietos
  }

  // =========================================================================
  // MAČO FINALIZAVIMAS IR BRACKET PERKĖLIMAS
  // =========================================================================

  static String? _winnerFromScores(
    int s1,
    int s2,
    String? player1Id,
    String? player2Id,
  ) {
    if (s1 > s2) return player1Id;
    if (s2 > s1) return player2Id;
    return null;
  }

  /// Vieningas kelias užbaigti mačą: winner_id, completed_at, bracket advance.
  static Future<void> finalizeMatchAndAdvance({
    required String matchId,
    int? scoreP1,
    int? scoreP2,
    String? completionNote,
    String? scoreStr,
  }) async {
    final client = Supabase.instance.client;
    final row = await client.from('matches').select().eq('id', matchId).single();
    final match = Map<String, dynamic>.from(row as Map);

    final s1 = scoreP1 ?? int.tryParse(match['score_p1'].toString()) ?? 0;
    final s2 = scoreP2 ?? int.tryParse(match['score_p2'].toString()) ?? 0;
    final winnerId = _winnerFromScores(
      s1,
      s2,
      match['player1_id']?.toString(),
      match['player2_id']?.toString(),
    );

    final updatePayload = <String, dynamic>{
      'status': 'completed',
      'winner_id': winnerId,
      'completed_at': DateTimeUtils.toIsoUtc(DateTime.now()),
      'dispute_reason': null,
      'dispute_created_at': null,
      'dispute_by_user_id': null,
    };
    if (scoreP1 != null) updatePayload['score_p1'] = s1;
    if (scoreP2 != null) updatePayload['score_p2'] = s2;

    if (completionNote != null || scoreStr != null) {
      final rawDetails = match['match_details'];
      final details = rawDetails is Map
          ? Map<String, dynamic>.from(rawDetails)
          : <String, dynamic>{};
      if (completionNote != null) {
        details['completion_note'] = completionNote;
      }
      if (scoreStr != null) {
        details['score_str'] = scoreStr;
      }
      updatePayload['match_details'] = details;
    }

    await client.from('matches').update(updatePayload).eq('id', matchId);

    match['score_p1'] = s1;
    match['score_p2'] = s2;
    match['winner_id'] = winnerId;
    match['status'] = 'completed';

    if (winnerId != null) {
      await moveWinnerToNextRound(match, winnerId);
    }
  }

  static Future<void> _assignPlayerToSlotIfNeeded(
    SupabaseClient client,
    String matchRowId,
    bool isPlayer1Slot,
    String playerId,
  ) async {
    final slotKey = isPlayer1Slot ? 'player1_id' : 'player2_id';
    final existing = await client
        .from('matches')
        .select(slotKey)
        .eq('id', matchRowId)
        .maybeSingle();
    if (existing == null) return;
    final current = existing[slotKey]?.toString();
    if (current == null || current.isEmpty || current == playerId) {
      await client
          .from('matches')
          .update({slotKey: playerId})
          .eq('id', matchRowId);
    }
  }

  /// Perkelia laimėtoją/pralaimėtoją į kitą raundą (single elimination).
  static Future<void> moveWinnerToNextRound(
    Map<String, dynamic> match,
    String winnerId,
  ) async {
    final client = Supabase.instance.client;
    final r = int.tryParse(match['round'].toString()) ?? 1;
    final m = int.tryParse(match['match_num'].toString()) ?? 1;
    final tId = match['tournament_id'].toString();
    final stage = match['stage'].toString();

    final loserId = match['player1_id'] == winnerId
        ? match['player2_id']?.toString()
        : match['player1_id']?.toString();

    final nextM = (m + 1) ~/ 2;
    final isP1 = (m % 2) != 0;

    final allMatches = await client
        .from('matches')
        .select('round')
        .eq('tournament_id', tId)
        .eq('stage', stage);
    var maxRound = 1;
    var hasThirdPlace = false;
    var hasAllPlaces = false;

    for (final mx in allMatches) {
      final rnd = int.tryParse(mx['round'].toString()) ?? 1;
      if (rnd < 50 && rnd > maxRound) maxRound = rnd;
      if (rnd == 99) hasThirdPlace = true;
      if (rnd == 50) hasAllPlaces = true;
    }

    if (r < 50) {
      if (r < maxRound) {
        final nextMatches = await client
            .from('matches')
            .select('id')
            .eq('tournament_id', tId)
            .eq('stage', stage)
            .eq('round', r + 1)
            .eq('match_num', nextM);
        if (nextMatches.isNotEmpty) {
          await _assignPlayerToSlotIfNeeded(
            client,
            nextMatches.first['id'].toString(),
            isP1,
            winnerId,
          );
        }
      }

      if (loserId != null) {
        if (r == maxRound - 1 && hasThirdPlace) {
          final thirdPlaceM = await client
              .from('matches')
              .select('id')
              .eq('tournament_id', tId)
              .eq('stage', stage)
              .eq('round', 99);
          if (thirdPlaceM.isNotEmpty) {
            await _assignPlayerToSlotIfNeeded(
              client,
              thirdPlaceM.first['id'].toString(),
              isP1,
              loserId,
            );
          }
        } else if (r == maxRound - 2 && hasAllPlaces) {
          final placementM = await client
              .from('matches')
              .select('id')
              .eq('tournament_id', tId)
              .eq('stage', stage)
              .eq('round', 50)
              .eq('match_num', nextM);
          if (placementM.isNotEmpty) {
            await _assignPlayerToSlotIfNeeded(
              client,
              placementM.first['id'].toString(),
              isP1,
              loserId,
            );
          }
        }
      }
    } else if (r == 50 && loserId != null) {
      final fifthPlaceM = await client
          .from('matches')
          .select('id')
          .eq('tournament_id', tId)
          .eq('stage', stage)
          .eq('round', 51);
      if (fifthPlaceM.isNotEmpty) {
        await _assignPlayerToSlotIfNeeded(
          client,
          fifthPlaceM.first['id'].toString(),
          isP1,
          winnerId,
        );
      }
      final seventhPlaceM = await client
          .from('matches')
          .select('id')
          .eq('tournament_id', tId)
          .eq('stage', stage)
          .eq('round', 52);
      if (seventhPlaceM.isNotEmpty) {
        await _assignPlayerToSlotIfNeeded(
          client,
          seventhPlaceM.first['id'].toString(),
          isP1,
          loserId,
        );
      }
    }
  }

  /// Užtikrina bracket perkėlimą po serverio auto-complete (be Flutter).
  static Future<void> reconcileBracketAdvances(String tournamentId) async {
    final client = Supabase.instance.client;
    final matches = await client
        .from('matches')
        .select()
        .eq('tournament_id', tournamentId)
        .eq('status', 'completed')
        .not('winner_id', 'is', null)
        .limit(QueryLimits.tournamentMatches);

    for (final raw in matches) {
      final match = Map<String, dynamic>.from(raw as Map);
      await moveWinnerToNextRound(match, match['winner_id'].toString());
    }
  }

  // =========================================================================
  // AUTOMATINIS RP IR XP IŠDALINIMAS BEI TURNYRO UŽDARYMAS
  // =========================================================================

  static Future<void> distributePointsAndCloseTournament(
    String tournamentId,
  ) async {
    final client = Supabase.instance.client;

    try {
      final tRes = await client
          .from('tournaments')
          .select()
          .eq('id', tournamentId)
          .single();
      if (tRes['status'] == 'completed') {
        throw Exception("Šis turnyras jau yra baigtas ir taškai išdalinti.");
      }

      int totalRpValue =
          int.tryParse(tRes['rp_value']?.toString() ?? '1000') ?? 1000;
      String sportName = tRes['sport'] ?? 'Tenisas';

      final matches = await client
          .from('matches')
          .select()
          .eq('tournament_id', tournamentId)
          .limit(QueryLimits.tournamentMatches);
      final participants = await client
          .from('tournament_participants')
          .select()
          .eq('tournament_id', tournamentId)
          .limit(QueryLimits.tournamentParticipants);

      if (participants.isEmpty) {
        throw Exception("Nėra dalyvių, kam dalinti taškus.");
      }

      Map<String, Map<String, dynamic>> playerStats = {};
      for (var p in participants) {
        String uid = p['user_id'] ?? '';
        if (uid.isNotEmpty) {
          playerStats[uid] = {
            'user_id': uid,
            'participant_id': p['id'],
            'matches_won': 0,
            'matches_played': 0, // PRIDĖTA: Skaičiuojame sužaistus mačus
            'highest_round': 0,
            'exact_place': 999,
          };
        }
      }

      int maxRoundPlayoff = 0;
      Map<String, dynamic>? finalMatch;
      Map<String, dynamic>? thirdPlaceMatch;

      for (var m in matches) {
        if (m['status'] == 'completed') {
          String? wId = m['winner_id'];
          String? p1 = m['player1_id'];
          String? p2 = m['player2_id'];
          int r = int.tryParse(m['round'].toString()) ?? 1;

          // Fiksuojame sužaistus mačus (išskyrus tuos, kur "Laisvas / BYE")
          bool isBye =
              m['match_details'] != null &&
              m['match_details']['score_str'] == 'BYE';

          if (!isBye) {
            if (p1 != null && playerStats.containsKey(p1)) {
              playerStats[p1]!['matches_played'] += 1;
            }
            if (p2 != null && playerStats.containsKey(p2)) {
              playerStats[p2]!['matches_played'] += 1;
            }
          }

          if (wId != null && playerStats.containsKey(wId)) {
            playerStats[wId]!['matches_won'] += 1;
          }

          if (r < 50 && r > maxRoundPlayoff) {
            maxRoundPlayoff = r;
            finalMatch = m;
          }
          if (r == 99) thirdPlaceMatch = m;

          if (r < 50) {
            if (p1 != null &&
                playerStats.containsKey(p1) &&
                r > playerStats[p1]!['highest_round']) {
              playerStats[p1]!['highest_round'] = r;
            }
            if (p2 != null &&
                playerStats.containsKey(p2) &&
                r > playerStats[p2]!['highest_round']) {
              playerStats[p2]!['highest_round'] = r;
            }
          }
        }
      }

      // SAUGIKLIAI NUO NULL TIKRINANT FINALUS
      if (finalMatch != null &&
          finalMatch['status'] == 'completed' &&
          finalMatch['winner_id'] != null) {
        String wId = finalMatch['winner_id'];
        String? lId = finalMatch['player1_id'] == wId
            ? finalMatch['player2_id']
            : finalMatch['player1_id'];
        if (playerStats.containsKey(wId)) playerStats[wId]!['exact_place'] = 1;
        if (lId != null && playerStats.containsKey(lId)) {
          playerStats[lId]!['exact_place'] = 2;
        }
      }

      if (thirdPlaceMatch != null &&
          thirdPlaceMatch['status'] == 'completed' &&
          thirdPlaceMatch['winner_id'] != null) {
        String wId = thirdPlaceMatch['winner_id'];
        String? lId = thirdPlaceMatch['player1_id'] == wId
            ? thirdPlaceMatch['player2_id']
            : thirdPlaceMatch['player1_id'];
        if (playerStats.containsKey(wId)) playerStats[wId]!['exact_place'] = 3;
        if (lId != null && playerStats.containsKey(lId)) {
          playerStats[lId]!['exact_place'] = 4;
        }
      }

      for (String uid in playerStats.keys) {
        int place = playerStats[uid]!['exact_place'];
        int highestRound = playerStats[uid]!['highest_round'];
        int matchesWon = playerStats[uid]!['matches_won'];
        int matchesPlayed = playerStats[uid]!['matches_played'];

        int earnedRp = 0;

        // --- 1. XP (archyvinis snapshot — profilyje skaičiuoja DB trigger per mačą) ---
        int earnedXp = (matchesWon * 25) +
            ((matchesPlayed - matchesWon).clamp(0, matchesPlayed) * 10);

        // --- 2. RP TAŠKAI (Pagal ATP Grand Slam stilių) ---
        if (place == 1) {
          earnedRp = totalRpValue;
        } else if (place == 2)
          earnedRp = (totalRpValue * 0.60).toInt();
        else if (place == 3)
          earnedRp = (totalRpValue * 0.40).toInt();
        else if (place == 4)
          earnedRp = (totalRpValue * 0.30).toInt();
        else if (highestRound == maxRoundPlayoff - 1 && maxRoundPlayoff > 1)
          earnedRp = (totalRpValue * 0.18).toInt(); // QF (Ketvirtfinalis)
        else if (highestRound == maxRoundPlayoff - 2 && maxRoundPlayoff > 2)
          earnedRp = (totalRpValue * 0.09).toInt(); // R16 (Aštuntfinalis)
        else
          earnedRp = (totalRpValue * 0.02).toInt(); // Paguoda / Base points

        await client
            .from('tournament_participants')
            .update({
              'earned_rp': earnedRp,
              'earned_xp': earnedXp,
              'final_place': place != 999 ? place : null,
            })
            .eq('id', playerStats[uid]!['participant_id']);

        await UserSportsService.awardRp(
          userId: uid,
          sportName: sportName,
          earnedRp: earnedRp,
          eventName: tRes['name']?.toString() ?? 'Turnyras',
        );
      }

      await client
          .from('tournaments')
          .update({'status': 'completed'})
          .eq('id', tournamentId);
    } catch (e) {
      debugPrint("Klaida uždarant turnyrą: $e");
      rethrow;
    }
  }
}
