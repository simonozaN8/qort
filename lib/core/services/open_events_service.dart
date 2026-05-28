import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/event_organizer_policy.dart';
import '../constants/query_limits.dart';

/// Vieši atviri renginiai ir turnyrai (kalendorius / „Atrask“).
class OpenEventsService {
  OpenEventsService._();

  static Future<List<dynamic>> loadOpenEvents({
    int limit = QueryLimits.tournamentList,
  }) async {
    final client = Supabase.instance.client;

    final eventsRes = await client
        .from('events')
        .select()
        .eq('status', 'open')
        .eq('approval_status', EventOrganizerPolicy.approvalApproved)
        .order('start_date')
        .limit(limit);

    final tournamentsRes = await client
        .from('tournaments')
        .select()
        .eq('status', 'open')
        .order('start_date')
        .limit(limit);

    final combined = <dynamic>[];

    for (final e in eventsRes) {
      e['is_parent_event'] = true;
      combined.add(e);
    }

    for (final t in tournamentsRes) {
      if (t['event_id'] == null) {
        t['is_parent_event'] = false;
        combined.add(t);
      }
    }

    combined.sort((a, b) {
      final dateA = a['start_date']?.toString() ?? '9999-12-31';
      final dateB = b['start_date']?.toString() ?? '9999-12-31';
      return dateA.compareTo(dateB);
    });

    if (combined.length > limit) {
      return combined.sublist(0, limit);
    }
    return combined;
  }
}
