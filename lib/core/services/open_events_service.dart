import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/event_organizer_policy.dart';
import '../constants/query_limits.dart';

/// Rikiavimo režimas turnyrų / renginių kalendoriui.
enum OpenEventsSortMode {
  /// Naujausi viršuje (created_at DESC).
  newest,

  /// Artimiausi pagal start_date; be datos — pabaigoje.
  soonest,
}

/// Vieši atviri renginiai ir turnyrai (kalendorius / „Atrask“).
class OpenEventsService {
  OpenEventsService._();

  static Future<List<dynamic>> loadOpenEvents({
    int limit = QueryLimits.tournamentList,
    OpenEventsSortMode sortMode = OpenEventsSortMode.newest,
  }) async {
    final client = Supabase.instance.client;

    final eventsBase = client
        .from('events')
        .select()
        .eq('status', 'open')
        .eq('approval_status', EventOrganizerPolicy.approvalApproved);

    final tournamentsBase = client
        .from('tournaments')
        .select()
        .eq('status', 'open');

    final List<dynamic> eventsRes;
    final List<dynamic> tournamentsRes;

    switch (sortMode) {
      case OpenEventsSortMode.newest:
        eventsRes = await eventsBase
            .order('created_at', ascending: false)
            .limit(limit);
        tournamentsRes = await tournamentsBase
            .order('created_at', ascending: false)
            .limit(limit);
        break;
      case OpenEventsSortMode.soonest:
        eventsRes = await eventsBase
            .order('start_date', ascending: true, nullsFirst: false)
            .limit(limit);
        tournamentsRes = await tournamentsBase
            .order('start_date', ascending: true, nullsFirst: false)
            .limit(limit);
        break;
    }

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

    combined.sort((a, b) => _compare(a, b, sortMode));

    if (combined.length > limit) {
      return combined.sublist(0, limit);
    }
    return combined;
  }

  static int _compare(
    dynamic a,
    dynamic b,
    OpenEventsSortMode sortMode,
  ) {
    switch (sortMode) {
      case OpenEventsSortMode.newest:
        final dateA = a['created_at']?.toString() ?? '';
        final dateB = b['created_at']?.toString() ?? '';
        return dateB.compareTo(dateA);
      case OpenEventsSortMode.soonest:
        final startA = a['start_date']?.toString();
        final startB = b['start_date']?.toString();
        final aMissing = startA == null || startA.isEmpty;
        final bMissing = startB == null || startB.isEmpty;
        if (aMissing && bMissing) return 0;
        if (aMissing) return 1;
        if (bMissing) return -1;
        return startA.compareTo(startB);
    }
  }
}
