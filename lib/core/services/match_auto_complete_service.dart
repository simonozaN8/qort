import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/query_limits.dart';

/// Mačų auto-patvirtinimas po 60 min.
/// XP paskirsto DB triggeris `on_match_completed_xp` (jei migracijos paleistos).
class MatchAutoCompleteService {
  static Future<void> processForUser(String userId) async {
    final client = Supabase.instance.client;

    List<dynamic> waiting;
    try {
      waiting = await client
          .from('matches')
          .select('id, match_details, updated_at, created_at')
          .or('player1_id.eq.$userId,player2_id.eq.$userId')
          .eq('status', 'played_waiting')
          .limit(QueryLimits.autoCompleteMatches);
    } on PostgrestException catch (e) {
      if (e.code != '42703') rethrow;
      waiting = await client
          .from('matches')
          .select('id, match_details, created_at')
          .or('player1_id.eq.$userId,player2_id.eq.$userId')
          .eq('status', 'played_waiting')
          .limit(QueryLimits.autoCompleteMatches);
    }

    for (final m in waiting) {
      DateTime? enteredAt;
      final details = m['match_details'];
      if (details is Map && details['score_entered_at'] != null) {
        enteredAt =
            DateTime.tryParse(details['score_entered_at'].toString())?.toLocal();
      } else if (m['updated_at'] != null) {
        enteredAt = DateTime.tryParse(m['updated_at'].toString())?.toLocal();
      } else if (m['created_at'] != null) {
        enteredAt = DateTime.tryParse(m['created_at'].toString())?.toLocal();
      }

      if (enteredAt == null) continue;
      if (DateTime.now().difference(enteredAt).inMinutes < 60) continue;

      await client
          .from('matches')
          .update({'status': 'completed'})
          .eq('id', m['id']);
    }
  }
}
