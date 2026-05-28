import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralizuota XP / RP logika per Supabase RPC (atominiu būdu).
class UserSportsService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> addXp(String userId, int xpToAdd) async {
    if (xpToAdd <= 0) return;
    try {
      await _client.rpc('increment_profile_xp', params: {
        'p_user_id': userId,
        'p_amount': xpToAdd,
      });
    } catch (e) {
      debugPrint('RPC increment_profile_xp nepavyko, fallback: $e');
      await _addXpFallback(userId, xpToAdd);
    }
  }

  static Future<void> _addXpFallback(String userId, int xpToAdd) async {
    try {
      final prof = await _client
          .from('profiles')
          .select('xp')
          .eq('id', userId)
          .maybeSingle();
      if (prof == null) return;
      final currentXp = (prof['xp'] as num?)?.toInt() ?? 0;
      await _client
          .from('profiles')
          .update({'xp': currentXp + xpToAdd})
          .eq('id', userId);
    } catch (_) {}
  }

  static Future<void> awardRp({
    required String userId,
    required String sportName,
    required int earnedRp,
    required String eventName,
  }) async {
    if (earnedRp == 0) return;
    try {
      await _client.rpc('award_user_sport_rp', params: {
        'p_user_id': userId,
        'p_sport': sportName,
        'p_earned_rp': earnedRp,
        'p_event_name': eventName,
      });
    } catch (e) {
      debugPrint('RPC award_user_sport_rp nepavyko, fallback: $e');
      await _awardRpFallback(
        userId: userId,
        sportName: sportName,
        earnedRp: earnedRp,
        eventName: eventName,
      );
    }
  }

  static Future<void> _awardRpFallback({
    required String userId,
    required String sportName,
    required int earnedRp,
    required String eventName,
  }) async {
    try {
      final existing = await _client
          .from('user_sports')
          .select('id, official_rp, rp_history')
          .eq('user_id', userId)
          .eq('sport', sportName)
          .maybeSingle();

      final now = DateTime.now().toIso8601String();

      if (existing != null) {
        final currentRp = (existing['official_rp'] as num?)?.toInt() ?? 1000;
        final newRp = currentRp + earnedRp;
        final history = existing['rp_history'] is List
            ? List<Map<String, dynamic>>.from(
                (existing['rp_history'] as List).map(
                  (e) => Map<String, dynamic>.from(e as Map),
                ),
              )
            : <Map<String, dynamic>>[];
        history.add({'rp': newRp, 'date': now, 'event': eventName});

        await _client.from('user_sports').update({
          'official_rp': newRp,
          'global_score': newRp,
          'rp_history': history,
        }).eq('id', existing['id']);
      } else {
        final newRp = 1000 + earnedRp;
        await _client.from('user_sports').insert({
          'user_id': userId,
          'sport': sportName,
          'level': 1,
          'official_rp': newRp,
          'global_score': newRp,
          'matches_won': 0,
          'matches_lost': 0,
          'rp_history': [
            {'rp': newRp, 'date': now, 'event': eventName},
          ],
        });
      }
    } catch (_) {}
  }
}
