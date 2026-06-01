import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/datetime_utils.dart';
import 'user_sports_service.dart';

/// Demo srautai: treniruočių skelbimas → priėmimas → mačas; Blitz taškai.
class DemoFlowResult {
  final bool ok;
  final String message;
  final String? noticeId;
  final String? matchId;

  const DemoFlowResult({
    required this.ok,
    required this.message,
    this.noticeId,
    this.matchId,
  });
}

class DemoFlowService {
  DemoFlowService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// 1) Sukuria skelbimą  2) „Priima“ varžovas (kitas profilis)  3) Sužaidžia mačą.
  static Future<DemoFlowResult> simulateTrainingSparring({
    required String userId,
    required String sportName,
    int level = 3,
    String? city,
  }) async {
    try {
      final opponentId = await _pickOpponentProfileId(userId);
      if (opponentId == null) {
        return const DemoFlowResult(
          ok: false,
          message:
              'Nerastas kitas profilis DB (reikia bent 2 vartotojų testui).',
        );
      }

      final matchDate = DateTime.now().add(const Duration(days: 2));
      final location = (city != null && city.isNotEmpty) ? city : 'Vilnius';

      // Leidžiame pakartotinai demo — pašaliname šiandienos skelbimus
      final startOfDay = DateTime.now()
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
          .toUtc()
          .toIso8601String();
      await _client
          .from('open_matches')
          .delete()
          .eq('creator_id', userId)
          .gte('created_at', startOfDay);

      final noticeRow = await _client
          .from('open_matches')
          .insert({
            'creator_id': userId,
            'sport': sportName,
            'level': level,
            'min_level': level > 1 ? level - 1 : 1,
            'max_level': level < 5 ? level + 1 : 5,
            'match_date': DateTimeUtils.toIsoUtc(matchDate),
            'location': location,
            'has_court': false,
            'court_price': '',
            'price_split': '',
            'format': '1v1',
            'is_team': false,
            'status': 'open',
          })
          .select('id')
          .single();

      final noticeId = noticeRow['id'] as String;

      await _client
          .from('open_matches')
          .update({'status': 'closed'})
          .eq('id', noticeId);

      final matchRow = await _client
          .from('matches')
          .insert({
            'player1_id': opponentId,
            'player2_id': userId,
            'match_date': DateTimeUtils.toIsoUtc(matchDate),
            'location': location,
            'status': 'scheduled',
          })
          .select('id')
          .single();

      final matchId = matchRow['id'] as String;

      await _client.from('matches').update({
        'status': 'completed',
        'winner_id': userId,
        'score_p1': 4,
        'score_p2': 6,
        'match_details': {'score_str': '4-6', 'demo': true},
      }).eq('id', matchId);

      await UserSportsService.addXp(userId, 15);
      await UserSportsService.addXp(opponentId, 10);

      return DemoFlowResult(
        ok: true,
        message:
            'Demo: skelbimas sukurtas, priimtas ir mačas užbaigtas (4-6). +15 XP.',
        noticeId: noticeId,
        matchId: matchId,
      );
    } catch (e, st) {
      debugPrint('Demo training klaida: $e\n$st');
      return DemoFlowResult(ok: false, message: 'Demo klaida: $e');
    }
  }

  /// Blitz: +BP profilyje (kol nėra atskiros Blitz lentelės).
  static Future<DemoFlowResult> simulateBlitzWin({
    required String userId,
    int bpGain = 35,
  }) async {
    try {
      final prof = await _client
          .from('profiles')
          .select('blitz_points')
          .eq('id', userId)
          .single();

      final current = (prof['blitz_points'] as num?)?.toInt() ?? 0;
      await _client
          .from('profiles')
          .update({'blitz_points': current + bpGain})
          .eq('id', userId);

      await UserSportsService.addXp(userId, 20);

      return DemoFlowResult(
        ok: true,
        message: 'Blitz demo: +$bpGain BP, +20 XP. Atidarykite Blitz rezultatą.',
      );
    } catch (e) {
      return DemoFlowResult(ok: false, message: 'Blitz demo klaida: $e');
    }
  }

  static Future<String?> _pickOpponentProfileId(String userId) async {
    final rows = await _client
        .from('profiles')
        .select('id')
        .neq('id', userId)
        .limit(5);
    if (rows.isEmpty) return null;
    return rows.first['id'] as String?;
  }
}
