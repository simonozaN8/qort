import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/event_organizer_policy.dart';

/// Vartotojo pasibaigusių / atšauktų turnyrų archyvas.
class EventArchiveService {
  EventArchiveService._();

  static final _client = Supabase.instance.client;

  static const _archiveStatuses = ['finished', 'cancelled'];

  /// Turnyrai kuriuose vartotojas dalyvavo (finished / cancelled).
  static Future<List<Map<String, dynamic>>> loadUserHistory({
    String? userId,
    String? sport,
    int? year,
    String? city,
  }) async {
    final uid = userId ?? _client.auth.currentUser?.id;
    if (uid == null) return [];

    var query = _client
        .from('events')
        .select('''
          *,
          tournaments(
            *,
            tournament_participants(user_id, final_place, earned_rp, earned_xp, team_name)
          )
        ''')
        .inFilter('status', _archiveStatuses)
        .eq('approval_status', EventOrganizerPolicy.approvalApproved);

    if (sport != null && sport != 'VISI') {
      query = query.eq('sport', sport);
    }
    if (city != null && city.isNotEmpty) {
      query = query.ilike('location', '%$city%');
    }
    if (year != null) {
      query = query
          .gte('start_date', '$year-01-01')
          .lte('start_date', '$year-12-31');
    }

    final data = List<Map<String, dynamic>>.from(
      await query.order('start_date', ascending: false),
    );

    return data.where((event) {
      final tournaments = event['tournaments'] as List? ?? [];
      for (final t in tournaments) {
        if (t is! Map) continue;
        final participants = t['tournament_participants'] as List? ?? [];
        if (participants.any((p) => p is Map && p['user_id']?.toString() == uid)) {
          return true;
        }
      }
      return false;
    }).toList();
  }
}
