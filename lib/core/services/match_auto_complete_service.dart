import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/match_constants.dart';
import '../constants/query_limits.dart';
import '../../features/tournament/tournament_engine.dart';

/// Mačų auto-patvirtinimas po 1 val. (MatchConstants.scoreConfirmationTimeout).
/// XP paskirsto DB triggeris `on_match_completed_xp` (jei migracijos paleistos).
class MatchAutoCompleteService {
  static DateTime? _scoreEnteredAt(Map<String, dynamic> match) {
    final details = match['match_details'];
    if (details is Map && details['score_entered_at'] != null) {
      return DateTime.tryParse(details['score_entered_at'].toString())?.toLocal();
    }
    if (match['submitted_at'] != null) {
      return DateTime.tryParse(match['submitted_at'].toString())?.toLocal();
    }
    if (match['updated_at'] != null) {
      return DateTime.tryParse(match['updated_at'].toString())?.toLocal();
    }
    if (match['created_at'] != null) {
      return DateTime.tryParse(match['created_at'].toString())?.toLocal();
    }
    return null;
  }

  static Future<void> processForUser(String userId) async {
    final client = Supabase.instance.client;

    List<dynamic> waiting;
    try {
      waiting = await client
          .from('matches')
          .select(
            'id, tournament_id, match_details, updated_at, created_at, submitted_at',
          )
          .or('player1_id.eq.$userId,player2_id.eq.$userId')
          .eq('status', 'played_waiting')
          .limit(QueryLimits.autoCompleteMatches);
    } on PostgrestException catch (e) {
      if (e.code != '42703') rethrow;
      waiting = await client
          .from('matches')
          .select('id, tournament_id, match_details, created_at')
          .or('player1_id.eq.$userId,player2_id.eq.$userId')
          .eq('status', 'played_waiting')
          .limit(QueryLimits.autoCompleteMatches);
    }

    final tournamentsToReconcile = <String>{};

    for (final m in waiting) {
      final match = Map<String, dynamic>.from(m as Map);
      final enteredAt = _scoreEnteredAt(match);
      if (enteredAt == null) continue;
      if (DateTime.now().difference(enteredAt) <
          MatchConstants.scoreConfirmationTimeout) {
        continue;
      }

      await TournamentEngine.finalizeMatchAndAdvance(
        matchId: match['id'].toString(),
        completionNote: MatchConstants.autoConfirmCompletionNote,
      );

      final tId = match['tournament_id']?.toString();
      if (tId != null && tId.isNotEmpty) {
        tournamentsToReconcile.add(tId);
      }
    }

    for (final tId in tournamentsToReconcile) {
      await TournamentEngine.reconcileBracketAdvances(tId);
    }
  }
}
