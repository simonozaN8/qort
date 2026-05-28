import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// „Draugai“ = žmonės, su kuriais buvo sąveika (komanda, mačai, įrašai).
/// Vėliau galima papildyti `follows` lentele — sujungti su [getConnectedUserIds].
class FriendsService {
  FriendsService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Visi susiję vartotojų ID (be savęs).
  static Future<Set<String>> getConnectedUserIds(String userId) async {
    final ids = <String>{};

    await Future.wait([
      _fromTeams(userId, ids),
      _fromMatches(userId, ids),
      _fromExternalRecords(userId, ids),
      _fromBlitzStub(userId, ids),
    ]);

    ids.remove(userId);
    return ids;
  }

  static Future<void> _fromTeams(String userId, Set<String> ids) async {
    try {
      final myTeams = await _client
          .from('team_members')
          .select('team_id')
          .eq('user_id', userId);

      final teamIds = (myTeams as List)
          .map((r) => r['team_id'] as String?)
          .whereType<String>()
          .toList();

      if (teamIds.isEmpty) return;

      final members = await _client
          .from('team_members')
          .select('user_id')
          .inFilter('team_id', teamIds);

      for (final row in members as List) {
        final uid = row['user_id'] as String?;
        if (uid != null && uid != userId) ids.add(uid);
      }
    } catch (e) {
      debugPrint('FriendsService._fromTeams: $e');
    }
  }

  static Future<void> _fromMatches(String userId, Set<String> ids) async {
    try {
      final rows = await _client
          .from('matches')
          .select('player1_id, player2_id')
          .or('player1_id.eq.$userId,player2_id.eq.$userId')
          .limit(200);

      for (final m in rows as List) {
        final p1 = m['player1_id'] as String?;
        final p2 = m['player2_id'] as String?;
        if (p1 != null && p1 != userId) ids.add(p1);
        if (p2 != null && p2 != userId) ids.add(p2);
      }
    } catch (e) {
      debugPrint('FriendsService._fromMatches: $e');
    }
  }

  static Future<void> _fromExternalRecords(String userId, Set<String> ids) async {
    try {
      final asOwner = await _client
          .from('external_records')
          .select('opponent_user_id')
          .eq('user_id', userId)
          .not('opponent_user_id', 'is', null)
          .limit(150);

      for (final r in asOwner as List) {
        final opp = r['opponent_user_id'] as String?;
        if (opp != null && opp != userId) ids.add(opp);
      }

      final asOpponent = await _client
          .from('external_records')
          .select('user_id')
          .eq('opponent_user_id', userId)
          .limit(150);

      for (final r in asOpponent as List) {
        final uid = r['user_id'] as String?;
        if (uid != null && uid != userId) ids.add(uid);
      }
    } catch (e) {
      debugPrint('FriendsService._fromExternalRecords: $e');
    }
  }

  /// Blitz mačų lentelės DB dar nėra — rezervuota follow / blitz_matches integracijai.
  static Future<void> _fromBlitzStub(String userId, Set<String> ids) async {
    // V1: tuščia. Ateityje: blitz_matches ar external_records su record_type = 'blitz'.
  }
}
