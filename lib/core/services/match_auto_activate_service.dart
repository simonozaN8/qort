import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/match_constants.dart';
import '../constants/query_limits.dart';

/// Pending → active, kai scheduled_time (ar match_date) + 15 min praėjo.
class MatchAutoActivateService {
  static DateTime? _scheduledAt(Map<String, dynamic> match) {
    final raw = match['scheduled_time'] ?? match['match_date'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  static bool _shouldActivate(Map<String, dynamic> match, DateTime nowUtc) {
    if (match['status']?.toString() != 'pending') return false;
    final scheduled = _scheduledAt(match);
    if (scheduled == null) return false;
    return nowUtc.isAfter(
      scheduled.add(MatchConstants.matchActivationGracePeriod),
    );
  }

  static Future<bool> _activateMatchIds(Iterable<String> ids) async {
    if (ids.isEmpty) return false;
    final client = Supabase.instance.client;
    var activated = false;

    for (final batch in _batches(ids.toList(), 50)) {
      await client
          .from('matches')
          .update({'status': 'active'})
          .inFilter('id', batch)
          .eq('status', 'pending');
      activated = true;
    }

    return activated;
  }

  static Iterable<List<T>> _batches<T>(List<T> items, int size) sync* {
    for (var i = 0; i < items.length; i += size) {
      final end = (i + size > items.length) ? items.length : i + size;
      yield items.sublist(i, end);
    }
  }

  /// Turnyro MAČAI tab — tik šio turnyro pending mačai.
  static Future<bool> processForTournament(String tournamentId) async {
    final client = Supabase.instance.client;
    final rows = await client
        .from('matches')
        .select('id, status, scheduled_time, match_date')
        .eq('tournament_id', tournamentId)
        .eq('status', 'pending')
        .limit(QueryLimits.tournamentMatches);

    final nowUtc = DateTime.now().toUtc();
    final ids = <String>[];
    for (final row in rows) {
      final match = Map<String, dynamic>.from(row as Map);
      if (_shouldActivate(match, nowUtc)) {
        ids.add(match['id'].toString());
      }
    }
    return _activateMatchIds(ids);
  }

  /// Home ekranas — vartotojo pending mačai.
  static Future<bool> processForUser(String userId) async {
    final client = Supabase.instance.client;
    final rows = await client
        .from('matches')
        .select('id, status, scheduled_time, match_date')
        .or('player1_id.eq.$userId,player2_id.eq.$userId')
        .eq('status', 'pending')
        .limit(QueryLimits.homeMatches);

    final nowUtc = DateTime.now().toUtc();
    final ids = <String>[];
    for (final row in rows) {
      final match = Map<String, dynamic>.from(row as Map);
      if (_shouldActivate(match, nowUtc)) {
        ids.add(match['id'].toString());
      }
    }
    return _activateMatchIds(ids);
  }

  /// Backup: esamas widget.matches sąrašas (ScheduleTab).
  static Future<bool> processListedMatches(List<dynamic> matches) async {
    final nowUtc = DateTime.now().toUtc();
    final ids = <String>[];
    for (final raw in matches) {
      final match = Map<String, dynamic>.from(raw as Map);
      if (_shouldActivate(match, nowUtc)) {
        ids.add(match['id'].toString());
      }
    }
    return _activateMatchIds(ids);
  }
}
