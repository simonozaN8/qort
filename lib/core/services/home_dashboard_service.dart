import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/query_limits.dart';
import 'match_auto_complete_service.dart';
import 'match_auto_activate_service.dart';
import 'user_profile_loader.dart';

class HomeDashboardData {
  final List<dynamic> allMatches;
  final List<dynamic> confirmedMatches;
  final List<dynamic> incomingProposals;
  final List<dynamic> unscheduledMatches;
  final List<dynamic> myTournaments;

  const HomeDashboardData({
    required this.allMatches,
    required this.confirmedMatches,
    required this.incomingProposals,
    required this.unscheduledMatches,
    required this.myTournaments,
  });

  /// Turnyrų progreso tekstai (liko kaip home_screen logikoje).
  static void enrichTournamentProgress({
    required List<dynamic> myTournaments,
    required List<dynamic> allMatches,
  }) {
    for (final t in myTournaments) {
      final tData = t['tournaments'];
      if (tData == null) continue;

      final tId = t['tournament_id'];
      final tMatches =
          allMatches.where((m) => m['tournament_id'] == tId).toList();
      final totalM = tMatches.length;
      final completedM =
          tMatches.where((m) => m['status'] == 'completed').length;

      double prog = 0.0;
      String statText = "";

      var isLadder = tData['format'] == 'Ladder (Piramidė)';
      if (tData['stages_config'] != null) {
        try {
          final stages = List<dynamic>.from(tData['stages_config']);
          if (stages.isNotEmpty &&
              stages[0]['format'].toString().contains('Ladder')) {
            isLadder = true;
          }
        } catch (_) {}
      }

      final endDt = tData['end_date'] != null
          ? DateTime.tryParse(tData['end_date'])
          : null;
      final startDt = tData['start_date'] != null
          ? DateTime.tryParse(tData['start_date'])
          : null;

      var daysLeft = 0;
      if (endDt != null) {
        daysLeft = endDt.difference(DateTime.now()).inDays;
      }

      if (isLadder) {
        if (startDt != null && endDt != null) {
          final totalSec = endDt.difference(startDt).inSeconds;
          final elapSec = DateTime.now().difference(startDt).inSeconds;
          if (totalSec > 0) prog = (elapSec / totalSec).clamp(0.0, 1.0);
        }
        statText = daysLeft > 0
            ? "Liko $daysLeft d."
            : (daysLeft == 0 ? "Baigiasi šiandien!" : "Baigėsi");
      } else {
        if (totalM > 0) {
          prog = completedM / totalM;
          statText = "Sužaista $completedM/$totalM";
        } else {
          statText = "Laukiama tvarkaraščio";
        }
        if (endDt != null && daysLeft >= 0 && totalM > 0) {
          statText += " (liko $daysLeft d.)";
        }
      }

      t['calculated_progress'] = prog;
      t['status_text'] = statText;
    }
  }
}

/// Pagrindinio ekrano duomenys — mačai, pasiūlymai, turnyrai.
class HomeDashboardService {
  HomeDashboardService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<HomeDashboardData> load(String userId) async {
    final myTourneysRes = await _client
        .from('tournament_participants')
        .select('tournament_id, tournaments(*)')
        .eq('user_id', userId)
        .limit(QueryLimits.myTournaments);

    await MatchAutoCompleteService.processForUser(userId);
    await MatchAutoActivateService.processForUser(userId);

    final myMatchesRes = await _client
        .from('matches')
        .select('*, tournaments(name, format, stages_config)')
        .or('player1_id.eq.$userId,player2_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(QueryLimits.homeMatches);

    final opponentIds = <String>{};
    for (final m in myMatchesRes) {
      if (m['player1_id'] != null && m['player1_id'] != userId) {
        opponentIds.add(m['player1_id'] as String);
      }
      if (m['player2_id'] != null && m['player2_id'] != userId) {
        opponentIds.add(m['player2_id'] as String);
      }
    }

    final oppNames =
        await UserProfileLoader.loadDisplayNames(opponentIds.toList());

    final confirmed = <dynamic>[];
    final incoming = <dynamic>[];
    final unscheduled = <dynamic>[];

    for (final m in myMatchesRes) {
      final oppId = (m['player1_id'] == userId)
          ? m['player2_id']
          : m['player1_id'];
      m['opponent_name'] = oppId != null
          ? (oppNames[oppId] ?? "Nežinomas varžovas")
          : "Laukia varžovo...";
      m['tournament_name'] = m['tournaments']?['name'] ?? "Turnyras";

      final status = m['status'] ?? 'pending';
      final isProposal = m['is_proposal_active'] == true;
      final hasTime =
          m['scheduled_time'] != null || m['match_date'] != null;

      var isLadder = false;
      final tData = m['tournaments'];
      if (tData != null) {
        if (tData['format']?.toString().contains('Ladder') == true ||
            tData['format']?.toString().contains('Piramidė') == true) {
          isLadder = true;
        }
        if (tData['stages_config'] != null) {
          try {
            final stages = tData['stages_config'] is List
                ? List.from(tData['stages_config'])
                : [tData['stages_config']];
            final stageConfig = stages.cast<dynamic>().firstWhere(
              (s) => s['id'] == m['stage'],
              orElse: () => null,
            );
            if (stageConfig != null &&
                (stageConfig['format']?.toString().contains('Ladder') ==
                        true ||
                    stageConfig['format']?.toString().contains('Piramidė') ==
                        true)) {
              isLadder = true;
            }
          } catch (_) {}
        }
      }

      if (status == 'active' ||
          status == 'scheduled' ||
          status == 'played_waiting' ||
          (status == 'pending' && hasTime && !isProposal)) {
        confirmed.add(m);
      } else if (status == 'pending' && oppId != null) {
        if (isProposal) {
          if (m['proposer_id'] != userId) {
            m['card_type'] = 'time_proposal';
            incoming.add(m);
          } else {
            unscheduled.add(m);
          }
        } else if (isLadder) {
          if (m['player2_id'] == userId) {
            m['card_type'] = 'ladder_challenge';
            incoming.add(m);
          } else {
            unscheduled.add(m);
          }
        } else {
          unscheduled.add(m);
        }
      }
    }

    return HomeDashboardData(
      allMatches: List<dynamic>.from(myMatchesRes),
      confirmedMatches: confirmed,
      incomingProposals: incoming,
      unscheduledMatches: unscheduled,
      myTournaments: List<dynamic>.from(myTourneysRes),
    );
  }
}
